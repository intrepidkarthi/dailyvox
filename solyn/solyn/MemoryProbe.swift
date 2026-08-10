//
//  MemoryProbe.swift
//  DailyVox
//
//  Measures what a workload actually costs this process in memory, on a real
//  iPhone, using the same ledger the kernel consults when it decides which app
//  to kill.
//
//  Why this exists: the v1.10 "your own voice" candidates (Kyutai Pocket TTS,
//  MOSS-TTS-Nano) are gated on a measured peak footprint, not a projected one.
//  The previous candidate — chatterbox-turbo — was projected to fit and then
//  measured 953.7 MB against a ~250 MB ceiling. Every number this file produces
//  is measured on device or it does not count.
//
//  DEBUG-only by construction: this is a development instrument, not a feature,
//  and the whole file compiles out of Release builds.
//

#if DEBUG

import Foundation
import Darwin
import os

// MARK: - Snapshot

/// One reading of the process's memory position, from `TASK_VM_INFO`.
///
/// The field that matters is ``physFootprint``, not resident size. Jetsam bills
/// a process for its phys_footprint — that is the number a model has to fit
/// inside. `resident_size` omits compressed pages and would flatter every
/// result we take.
struct MemorySnapshot: Codable, Sendable {

    /// What jetsam bills this process for. The number that decides life or death.
    let physFootprint: UInt64

    /// Kernel-tracked high-water mark of ``physFootprint`` for the life of this
    /// process. There is no user-space call to reset it, which is the whole
    /// reason ``PeakConfidence`` exists.
    let ledgerPeak: Int64

    /// Bytes remaining before this process hits its jetsam limit. `nil` on
    /// kernels that predate the field (rev4).
    let limitBytesRemaining: UInt64?

    /// Footprint attributed to Neural Engine allocations. A CoreML or
    /// ExecuTorch model executing on the ANE appears here *as well as* in
    /// ``physFootprint`` — it is not a separate budget, it is a breakdown.
    let neuralFootprint: Int64?

    /// Compressed-memory footprint. Watch this on calibration runs: if a
    /// workload's pages are compressible, the footprint understates what an
    /// equivalent volume of real model weights would cost.
    let compressed: UInt64

    /// `os_proc_available_memory()` — headroom as the OS reports it to apps.
    /// Independent of ``limitBytesRemaining`` and worth cross-checking against it.
    let availableMemory: Int

    /// Wall-clock offset from the start of the run, in seconds. Zero for
    /// one-shot reads.
    var elapsed: TimeInterval = 0
}

// MARK: - Reading the ledger

enum MemoryProbe {

    /// Reads `TASK_VM_INFO` for the current process.
    ///
    /// Fields arrived in the struct over successive kernel revisions, and the
    /// kernel reports back how much it actually filled in. We ask for the full
    /// struct and then only trust a field if the returned count covers it —
    /// reading past that boundary yields whatever was on the stack, which is
    /// exactly the kind of plausible-looking garbage this harness exists to
    /// avoid.
    static func snapshot() -> MemorySnapshot? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return MemorySnapshot(
            physFootprint: info.phys_footprint,
            ledgerPeak: info.ledger_phys_footprint_peak,
            limitBytesRemaining: filled(count, \.limit_bytes_remaining, size: 8)
                ? info.limit_bytes_remaining : nil,
            neuralFootprint: filled(count, \.ledger_tag_neural_footprint, size: 8)
                ? info.ledger_tag_neural_footprint : nil,
            compressed: info.compressed,
            availableMemory: os_proc_available_memory()
        )
    }

    /// Did the kernel fill in far enough to cover this field?
    ///
    /// `count` comes back in units of `natural_t`, so a field is safe to read
    /// only once the reported count reaches past the field's last byte.
    private static func filled(
        _ count: mach_msg_type_number_t,
        _ keyPath: PartialKeyPath<task_vm_info_data_t>,
        size: Int
    ) -> Bool {
        guard let offset = MemoryLayout<task_vm_info_data_t>.offset(of: keyPath) else {
            return false
        }
        let unit = MemoryLayout<natural_t>.size
        let needed = (offset + size + unit - 1) / unit
        return Int(count) >= needed
    }
}

// MARK: - Peak confidence

/// How much a reported peak can be trusted.
///
/// The kernel's high-water mark cannot be reset from user space, so a workload
/// that stays below a mark set earlier in the process's life leaves the ledger
/// untouched. When that happens we fall back to the sampler, which can miss a
/// spike shorter than its interval. The distinction is the difference between a
/// number you can gate a release on and one you cannot, so it travels with
/// every result rather than living in a footnote.
enum PeakConfidence: String, Codable, Sendable {

    /// The workload pushed the process to a new lifetime high, so the kernel
    /// ledger recorded the peak itself. Exact: no sampling gap can hide a spike.
    case exact

    /// The workload stayed under a high-water mark set earlier in this process's
    /// life. The reported peak is the highest value the sampler observed and is
    /// a **lower bound** — relaunch the app and re-run to get an exact reading.
    case sampled

    var summary: String {
        switch self {
        case .exact: return "Exact — kernel high-water mark"
        case .sampled: return "Lower bound — sampled, relaunch to confirm"
        }
    }
}

// MARK: - Sampler

/// Polls `phys_footprint` on a dedicated thread for the duration of a workload.
///
/// Sampling exists only to cover the ``PeakConfidence/sampled`` case. When the
/// ledger moves, the ledger wins — it is exact and this is not.
private final class FootprintSampler {

    private struct State {
        var running = true
        var peak: UInt64 = 0
        var samples = 0
        var trace: [MemorySnapshot] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let interval: useconds_t
    private let traceEvery: Int
    private var thread: Thread?

    /// - Parameters:
    ///   - interval: microseconds between reads. 500 µs keeps the thread under
    ///     ~1% of a core while being fine enough to catch a model load.
    ///   - traceEvery: keep one snapshot per N samples for the timeline, so a
    ///     long run does not accumulate an unbounded array.
    init(interval: useconds_t = 500, traceEvery: Int = 40) {
        self.interval = interval
        self.traceEvery = traceEvery
    }

    func start(startedAt: Date) {
        let thread = Thread { [state, interval, traceEvery] in
            while state.withLock({ $0.running }) {
                if var reading = MemoryProbe.snapshot() {
                    reading.elapsed = Date().timeIntervalSince(startedAt)
                    state.withLock { current in
                        current.peak = max(current.peak, reading.physFootprint)
                        current.samples += 1
                        if current.samples % traceEvery == 0 {
                            current.trace.append(reading)
                        }
                    }
                }
                usleep(interval)
            }
        }
        thread.qualityOfService = .userInitiated
        thread.name = "MemoryProbe.sampler"
        self.thread = thread
        thread.start()
    }

    /// Stops the thread and returns what it saw.
    func stop() -> (peak: UInt64, samples: Int, trace: [MemorySnapshot]) {
        state.withLock { $0.running = false }
        // The sampler checks the flag once per interval; give it a couple of
        // intervals to notice and exit before we read the final state.
        usleep(interval * 3)
        return state.withLock { ($0.peak, $0.samples, $0.trace) }
    }
}

// MARK: - Result

/// What one measured workload cost.
struct MemoryProbeResult: Codable, Sendable, Identifiable {
    var id: String { "\(label)-\(startedAt.timeIntervalSince1970)" }

    let label: String
    let startedAt: Date
    let duration: TimeInterval

    /// Footprint immediately before the workload ran.
    let baseline: UInt64
    /// Highest footprint observed during the workload.
    let peak: UInt64
    /// Footprint after the workload returned and its allocations were released.
    let settled: UInt64

    let confidence: PeakConfidence
    let sampleCount: Int
    let trace: [MemorySnapshot]

    /// Snapshot taken at the moment of peak-adjacent measurement, for the ANE
    /// and jetsam-headroom fields.
    let atPeak: MemorySnapshot?

    /// Device and OS, because the jetsam limit is per-device and a number
    /// without its device is not a result.
    let device: String
    let systemVersion: String
    let physicalMemory: UInt64

    /// What the workload itself cost, over the process baseline. This is the
    /// number a model budget is spent against.
    var peakDelta: Int64 { Int64(peak) - Int64(baseline) }

    /// Memory not returned when the workload finished. Persistently non-zero
    /// means a leak or a cache that outlives the run — either way, the next
    /// run's baseline is polluted.
    var retained: Int64 { Int64(settled) - Int64(baseline) }
}

// MARK: - Runner

extension MemoryProbe {

    /// Measures the peak footprint cost of `work`.
    ///
    /// Runs `work` synchronously on the calling thread while a sampler watches
    /// from another. Call this off the main thread for anything slow.
    ///
    /// - Note: Relaunch the app before a measurement that matters. The kernel's
    ///   high-water mark only ever rises, so a fresh process is what buys an
    ///   ``PeakConfidence/exact`` reading.
    ///
    /// - Important: Only one measurement may be in flight at a time, and nothing
    ///   else in the app should be doing heavy work while one runs. This reads
    ///   the *process* footprint, so a concurrent allocation anywhere is
    ///   indistinguishable from the workload's own. The test suite establishes
    ///   this the hard way: running these measurements in parallel made them
    ///   fail non-deterministically until the suite was marked `.serialized`.
    static func measure(
        label: String,
        settleDelay: TimeInterval = 0.5,
        work: () throws -> Void
    ) rethrows -> MemoryProbeResult {

        let before = snapshot()
        let baseline = before?.physFootprint ?? 0
        let ledgerBefore = before?.ledgerPeak ?? 0

        let startedAt = Date()
        let sampler = FootprintSampler()
        sampler.start(startedAt: startedAt)

        // `defer` so a throwing workload still stops the thread.
        var stopped: (peak: UInt64, samples: Int, trace: [MemorySnapshot])?
        defer { if stopped == nil { _ = sampler.stop() } }

        try work()

        let duration = Date().timeIntervalSince(startedAt)
        let atPeak = snapshot()
        let result = sampler.stop()
        stopped = result

        let ledgerAfter = atPeak?.ledgerPeak ?? 0

        // If the workload moved the kernel's high-water mark, the kernel saw the
        // true peak and the sampler is irrelevant. Otherwise the sampler's best
        // observation is all we have, and it is a lower bound.
        let confidence: PeakConfidence = ledgerAfter > ledgerBefore ? .exact : .sampled
        let peak = confidence == .exact
            ? UInt64(max(0, ledgerAfter))
            : max(result.peak, baseline)

        // Let deallocation and the compressor settle before reading what stuck.
        Thread.sleep(forTimeInterval: settleDelay)
        let settled = snapshot()?.physFootprint ?? baseline

        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { raw in
            Array(raw.prefix { $0 != 0 })
        }

        return MemoryProbeResult(
            label: label,
            startedAt: startedAt,
            duration: duration,
            baseline: baseline,
            peak: peak,
            settled: settled,
            confidence: confidence,
            sampleCount: result.samples,
            trace: result.trace,
            atPeak: atPeak,
            device: String(decoding: machine, as: UTF8.self),
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            physicalMemory: ProcessInfo.processInfo.physicalMemory
        )
    }
}

// MARK: - Calibration

/// Workloads whose true cost is known in advance, used to check that the
/// harness reports what actually happened.
///
/// This is the step that separates this harness from the projection that killed
/// chatterbox-turbo. If a run that allocates a known 200 MB does not measure as
/// ~200 MB, then no reading this file produces about a TTS model means anything
/// either, and that has to be discovered here rather than after a shipping
/// decision.
enum MemoryCalibration {

    /// Allocates `megabytes` of **incompressible** memory, touches every page so
    /// it is genuinely resident, and holds it until the closure returns.
    ///
    /// Incompressible matters. iOS compresses idle pages, and phys_footprint
    /// counts compressed pages at their compressed size — so a calibration that
    /// wrote zeros would compress to almost nothing and report a wildly
    /// optimistic number. Model weights do not compress; neither does this.
    static func holdingIncompressible(
        megabytes: Int,
        _ body: (UnsafeMutableRawPointer) -> Void = { _ in }
    ) {
        let byteCount = megabytes * 1024 * 1024
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: MemoryLayout<UInt64>.alignment
        )
        defer { buffer.deallocate() }

        // A cheap xorshift PRNG: deterministic, and its output does not compress.
        var seed: UInt64 = 0x2545F4914F6CDD1D
        let stride = MemoryLayout<UInt64>.size
        let words = byteCount / stride
        let typed = buffer.bindMemory(to: UInt64.self, capacity: words)
        for index in 0..<words {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            typed[index] = seed
        }

        body(buffer)
    }

    /// Runs a calibration at `megabytes` and reports how far the harness's
    /// measurement landed from the known truth.
    static func verify(megabytes: Int) -> (result: MemoryProbeResult, errorPercent: Double) {
        let result = MemoryProbe.measure(label: "Calibration \(megabytes) MB") {
            holdingIncompressible(megabytes: megabytes) { _ in
                // Hold briefly at peak so a sampled reading has a chance to see
                // it. An exact reading does not need this; a sampled one does.
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        let expected = Double(megabytes) * 1024 * 1024
        let error = (Double(result.peakDelta) - expected) / expected * 100
        return (result, error)
    }
}

// MARK: - Formatting

extension MemoryProbeResult {

    static func format(bytes: Int64) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if abs(mb) >= 1024 {
            return String(format: "%.2f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    static func format(bytes: UInt64) -> String { format(bytes: Int64(bytes)) }

    /// A one-line summary suitable for pasting into a decision record.
    var headline: String {
        "\(label): peak +\(Self.format(bytes: peakDelta)) over a "
            + "\(Self.format(bytes: baseline)) baseline "
            + "(\(confidence.rawValue), \(device), \(systemVersion))"
    }
}

// MARK: - Export

enum MemoryProbeExport {

    /// Writes results as JSON to a temporary file for the share sheet.
    static func write(_ results: [MemoryProbeResult]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dailyvox-memory-probe-\(stamp).json")

        try encoder.encode(results).write(to: url)
        return url
    }
}

#endif
