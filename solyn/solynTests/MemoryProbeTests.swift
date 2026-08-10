//
//  MemoryProbeTests.swift
//  solynTests
//
//  Checks that the memory harness measures what actually happened.
//
//  These run on the simulator, where absolute footprints are not
//  device-representative — the simulator is a macOS process with a different
//  allocator and no jetsam limit. What they establish is that the *arithmetic*
//  is right: that a known allocation reads back as that allocation, that peak
//  and baseline are not transposed, and that the confidence flag reports what it
//  claims. A device run inherits correct math instead of having to establish it.
//

#if DEBUG

import Testing
import Foundation
@testable import solyn

/// Serialized deliberately. `MemoryProbe` measures the whole process, so two of
/// these running at once each see the other's allocations as their own baseline
/// and peak. Running them in parallel — swift-testing's default — made this
/// suite fail non-deterministically before the trait was added, which is the
/// same hazard as taking a model measurement while anything else in the app is
/// busy.
@Suite(.serialized)
struct MemoryProbeTests {

    @Test func snapshotReturnsPlausibleValues() throws {
        let snapshot = try #require(MemoryProbe.snapshot(), "TASK_VM_INFO should be readable")

        #expect(snapshot.physFootprint > 0)
        // Any running process has a nonzero footprint but is not using the
        // whole machine; a wild value here means the struct is misaligned and
        // we are reading the wrong field.
        #expect(snapshot.physFootprint < ProcessInfo.processInfo.physicalMemory)
        #expect(snapshot.ledgerPeak >= Int64(snapshot.physFootprint))
    }

    @Test func peakNeverPrecedesBaseline() {
        let result = MemoryProbe.measure(label: "no-op") { }
        #expect(result.peak >= result.baseline, "peak must include the baseline it is measured from")
        #expect(result.duration >= 0)
    }

    /// The load-bearing test. A known volume of incompressible bytes must read
    /// back as that volume — this is the check that would have caught the
    /// chatterbox-turbo projection before it became a decision.
    @Test func calibrationMeasuresWhatItAllocated() {
        let megabytes = 128
        let (result, errorPercent) = MemoryCalibration.verify(megabytes: megabytes)

        let expected = Int64(megabytes) * 1024 * 1024
        #expect(
            result.peakDelta > expected / 2,
            "measured \(MemoryProbeResult.format(bytes: result.peakDelta)) for a \(megabytes) MB allocation — the harness is under-reporting by more than half"
        )
        #expect(
            abs(errorPercent) < 25,
            "calibration error \(String(format: "%.1f%%", errorPercent)) exceeds the 25% band; no model measurement from this harness would be trustworthy"
        )
    }

    /// Incompressible input is the point: zero-filled pages compress to almost
    /// nothing and would make every measurement look better than it is.
    @Test func calibrationBufferDoesNotCompress() {
        var distinctBytes = Set<UInt8>()
        MemoryCalibration.holdingIncompressible(megabytes: 1) { buffer in
            let bytes = buffer.assumingMemoryBound(to: UInt8.self)
            for index in stride(from: 0, to: 1024 * 1024, by: 997) {
                distinctBytes.insert(bytes[index])
            }
        }
        // A zero-filled or trivially patterned buffer would show a handful of
        // distinct values; noise fills the byte space.
        #expect(distinctBytes.count > 200, "calibration buffer is patterned, so it would compress")
    }

    @Test func releasedMemoryIsNotRetained() {
        let result = MemoryProbe.measure(label: "transient 64 MB") {
            MemoryCalibration.holdingIncompressible(megabytes: 64) { _ in }
        }
        // The allocation is freed inside the workload, so almost none of it
        // should still be charged to us afterwards. A large positive number here
        // means the next measurement starts from a polluted baseline.
        #expect(
            result.retained < 32 * 1024 * 1024,
            "retained \(MemoryProbeResult.format(bytes: result.retained)) after freeing 64 MB"
        )
    }

    @Test func resultsRoundTripThroughJSON() throws {
        let result = MemoryProbe.measure(label: "export") { }
        let url = try MemoryProbeExport.write([result])
        defer { try? FileManager.default.removeItem(at: url) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([MemoryProbeResult].self, from: Data(contentsOf: url))

        #expect(decoded.count == 1)
        #expect(decoded.first?.label == "export")
        #expect(decoded.first?.peak == result.peak)
    }

    @Test func confidenceIsExactWhenTheLedgerMoves() {
        // Allocating well past anything this test process has touched should set
        // a new lifetime high-water mark, which is the condition for an exact
        // reading. If this ever reports sampled, the ledger comparison is wrong.
        let (result, _) = MemoryCalibration.verify(megabytes: 256)
        #expect(
            result.confidence == .exact,
            "a 256 MB allocation should move the kernel high-water mark; got \(result.confidence.rawValue)"
        )
    }
}

#endif
