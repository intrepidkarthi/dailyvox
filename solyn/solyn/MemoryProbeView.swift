//
//  MemoryProbeView.swift
//  DailyVox
//
//  The on-device face of MemoryProbe: run a workload, read what it cost, share
//  the JSON. Exists so the v1.10 voice measurement can be taken on the phone
//  itself rather than from an Xcode session — the same constraint the app holds
//  for features applies to the instrument that gates them.
//
//  DEBUG-only, like the probe it drives.
//

#if DEBUG

import SwiftUI

struct MemoryProbeView: View {

    @State private var results: [MemoryProbeResult] = []
    @State private var running: String?
    @State private var live: MemorySnapshot?
    @State private var exportURL: URL?
    @State private var exportError: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            liveSection
            calibrationSection
            if !results.isEmpty { resultsSection }
            guidanceSection
        }
        .navigationTitle("Memory Probe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { live = MemoryProbe.snapshot() }
        .onReceive(timer) { _ in if running == nil { live = MemoryProbe.snapshot() } }
        .sheet(item: Binding(
            get: { exportURL.map { IdentifiableURL(url: $0) } },
            set: { if $0 == nil { exportURL = nil } }
        )) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("Export error", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Live

    private var liveSection: some View {
        Section {
            if let live {
                row("Footprint", MemoryProbeResult.format(bytes: live.physFootprint))
                row("Lifetime peak", MemoryProbeResult.format(bytes: live.ledgerPeak))
                if let remaining = live.limitBytesRemaining {
                    row("Headroom to jetsam", MemoryProbeResult.format(bytes: remaining))
                }
                row("OS reports available", MemoryProbeResult.format(bytes: Int64(live.availableMemory)))
                if let neural = live.neuralFootprint, neural > 0 {
                    row("Neural Engine", MemoryProbeResult.format(bytes: neural))
                }
                row("Compressed", MemoryProbeResult.format(bytes: live.compressed))
            } else {
                Text("TASK_VM_INFO unavailable")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Live")
        } footer: {
            Text("Footprint is what jetsam bills this process for — not resident size, which omits compressed pages. The lifetime peak only ever rises, so relaunch the app before a run that matters.")
        }
    }

    // MARK: - Calibration

    private var calibrationSection: some View {
        Section {
            ForEach([50, 100, 250], id: \.self) { megabytes in
                Button {
                    runCalibration(megabytes: megabytes)
                } label: {
                    HStack {
                        Text("Allocate \(megabytes) MB")
                        Spacer()
                        if running == "Calibration \(megabytes) MB" {
                            ProgressView()
                        }
                    }
                }
                .disabled(running != nil)
            }
        } header: {
            Text("Calibration")
        } footer: {
            Text("Allocates a known volume of incompressible bytes and checks that the harness measures what it actually allocated. Run this first: if a known 250 MB does not read as ~250 MB, no number this screen reports about a TTS model means anything either. That is the mistake that cost the chatterbox-turbo evaluation.")
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        Section {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(result.label)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(MemoryProbeResult.format(bytes: result.peakDelta))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(DS.Palette.gold)
                    }
                    Text(result.confidence.summary)
                        .font(.caption)
                        .foregroundColor(result.confidence == .exact ? .secondary : .orange)
                    Text("baseline \(MemoryProbeResult.format(bytes: result.baseline)) · retained \(MemoryProbeResult.format(bytes: result.retained)) · \(result.sampleCount) samples · \(String(format: "%.2fs", result.duration))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }

            Button {
                share()
            } label: {
                Label("Export results as JSON", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                results.removeAll()
            } label: {
                Text("Clear")
            }
        } header: {
            Text("Results")
        } footer: {
            Text("Peak delta is the workload's own cost over the process baseline — the number a model budget is spent against. Retained is what did not come back; persistently non-zero means the next run starts from a polluted baseline.")
        }
    }

    private var guidanceSection: some View {
        Section {
            Text("Running a model measurement")
                .font(.subheadline.weight(.semibold))
            Text("1. Force-quit and relaunch DailyVox, so the lifetime peak is low and the reading comes back exact rather than sampled.\n2. Run a calibration at roughly the size you expect, and confirm the error is small.\n3. Run the model workload once, cold.\n4. Export before doing anything else — a second run's baseline includes whatever the first one retained.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Protocol")
        } footer: {
            Text("A measurement taken inside the full app is the one that counts: jetsam bills the whole process, so a model measured alone in a bare harness reports a number the app can never actually achieve.")
        }
    }

    // MARK: - Actions

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    private func runCalibration(megabytes: Int) {
        let label = "Calibration \(megabytes) MB"
        running = label
        // Off the main thread: the workload is synchronous and would otherwise
        // block the sampler's own scheduling as well as the UI.
        DispatchQueue.global(qos: .userInitiated).async {
            let (result, errorPercent) = MemoryCalibration.verify(megabytes: megabytes)
            DispatchQueue.main.async {
                // Fold the calibration error into the label so it survives
                // export and screenshotting alongside the number it qualifies.
                let annotated = MemoryProbeResult(
                    label: "\(result.label) (error \(String(format: "%+.1f%%", errorPercent)))",
                    startedAt: result.startedAt,
                    duration: result.duration,
                    baseline: result.baseline,
                    peak: result.peak,
                    settled: result.settled,
                    confidence: result.confidence,
                    sampleCount: result.sampleCount,
                    trace: result.trace,
                    atPeak: result.atPeak,
                    device: result.device,
                    systemVersion: result.systemVersion,
                    physicalMemory: result.physicalMemory
                )
                results.insert(annotated, at: 0)
                running = nil
                live = MemoryProbe.snapshot()
            }
        }
    }

    private func share() {
        do {
            exportURL = try MemoryProbeExport.write(results)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

#endif
