//
//  SpeechLocaleProbeView.swift
//  DailyVox
//
//  The on-device face of SpeechLocaleProbe: run it, read it, copy it.
//
//  DEBUG-only, like the probe it drives.
//

#if DEBUG && os(iOS)

import SwiftUI
import UIKit

struct SpeechLocaleProbeView: View {

    @State private var report: SpeechLocaleProbeReport?
    @State private var running = false
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                Button(running ? "Probing…" : "Run probe") {
                    Task { await run() }
                }
                .disabled(running)
                if let report {
                    Button(copied ? "Copied" : "Copy report") {
                        UIPasteboard.general.string = report.text
                        copied = true
                    }
                }
            } footer: {
                Text("Run on iOS 26 and on 17/18, before and after installing the Hindi dictation model (Settings > General > Keyboard > Dictation). Gates plan decision D2.")
            }

            if let report {
                Section("Report") {
                    Text(report.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Speech Locale Probe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func run() async {
        running = true
        copied = false
        report = await SpeechLocaleProbe.run()
        running = false
    }
}

#endif
