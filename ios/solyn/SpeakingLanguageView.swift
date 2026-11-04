//
//  SpeakingLanguageView.swift
//  solyn
//
//  Settings > Language you speak (plan B-6).
//

#if os(iOS)
import SwiftUI

/// Picks the one language DailyVox listens in, separately from the app's
/// language. Lists only what this iPhone can transcribe on-device, now or
/// after a one-time download from Apple; see `SpeakingLanguage`.
struct SpeakingLanguageView: View {

    @State private var options: [SpeakingLanguage.Option] = []
    @State private var loaded = false
    @State private var chosen: String? = SpeakingLanguage.chosenIdentifier
    @State private var pendingDownload: SpeakingLanguage.Option?
    @State private var downloading: String?
    @State private var progress: Double = 0
    @State private var errorMessage: String?

    private var automatic: Locale { SpeechTranscriber.automaticSpeakerLocale }

    var body: some View {
        List {
            Section {
                Button {
                    select(nil)
                } label: {
                    row(title: String(localized: "Automatic",
                                      comment: "Language you speak: follow the iPhone's own language."),
                        subtitle: String(localized: "Your iPhone's language: \(SpeakingLanguage.displayName(of: automatic))",
                                         comment: "Language you speak: under Automatic. The placeholder is a language name, e.g. 'Hindi (India)'."),
                        selected: chosen == nil)
                }
                .buttonStyle(.plain)
            } footer: {
                if loaded, SpeakingLanguage.option(for: automatic, in: options) == nil {
                    Text(SpeakingLanguage.cannotTranscribeCopy(for: automatic))
                }
            }

            Section {
                if !loaded {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Asking this iPhone which languages it can hear…",
                             comment: "Language you speak: shown while the list of on-device speech models loads.")
                            .font(.dv(.subheadline))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(options) { option in
                        Button {
                            tapped(option)
                        } label: {
                            optionRow(option)
                        }
                        .buttonStyle(.plain)
                        .disabled(downloading != nil)
                    }
                }
            } header: {
                Text("Languages this iPhone can hear",
                     comment: "Language you speak: header above the list of languages.")
            } footer: {
                Text("Transcribed on this iPhone. Nothing you say is sent anywhere.",
                     comment: "Language you speak: footer under the list of languages.")
            }
        }
        .navigationTitle(String(localized: "Language you speak",
                                comment: "Settings: title of the screen that picks the language DailyVox listens in."))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            Text(SpeakingLanguage.explainerCopy)
                .font(.dv(.footnote))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.bar)
        }
        .task {
            options = await SpeakingLanguage.availableOptions()
            loaded = true
        }
        .alert(String(localized: "Download this language?",
                      comment: "Language you speak: title of the alert before a one-time model download."),
               isPresented: Binding(get: { pendingDownload != nil },
                                    set: { if !$0 { pendingDownload = nil } }),
               presenting: pendingDownload) { option in
            Button(String(localized: "Download", comment: "Language you speak: confirm the model download.")) {
                download(option)
            }
            Button(String(localized: "Cancel", comment: "Language you speak: cancel the model download."), role: .cancel) {}
        } message: { option in
            Text(SpeakingLanguage.downloadCopy(for: option.locale))
        }
        .alert(String(localized: "Couldn't download",
                      comment: "Language you speak: title of the alert when a model download fails."),
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button(String(localized: "OK", comment: "Dismiss an alert."), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Rows

    private func optionRow(_ option: SpeakingLanguage.Option) -> some View {
        let subtitle: String
        if downloading == option.identifier {
            subtitle = String(localized: "Downloading from Apple… \(Int((progress * 100).rounded()))%",
                              comment: "Language you speak: a model download in progress. The placeholder is a percentage number.")
        } else if option.installed {
            subtitle = String(localized: "On this iPhone",
                              comment: "Language you speak: the speech model for this language is already installed.")
        } else {
            subtitle = String(localized: "One-time download from Apple",
                              comment: "Language you speak: the speech model for this language must be downloaded once.")
        }
        return row(title: option.displayName(), subtitle: subtitle,
                   selected: chosen == option.identifier)
    }

    private func row(title: String, subtitle: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.dv(.body))
                Text(subtitle)
                    .font(.dv(.caption))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark")
                    .font(.dv(.subheadline, weight: .semibold))
                    .foregroundColor(DS.Palette.gold)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Actions

    private func tapped(_ option: SpeakingLanguage.Option) {
        if option.installed || option.engine == .legacyOnDevice {
            select(option.identifier)
        } else {
            pendingDownload = option
        }
    }

    private func select(_ identifier: String?) {
        chosen = identifier
        SpeakingLanguage.chosenIdentifier = identifier
        HapticManager.shared.selectionChanged()
    }

    private func download(_ option: SpeakingLanguage.Option) {
        downloading = option.identifier
        progress = 0
        Task {
            do {
                try await SpeakingLanguage.install(option) { progress = $0 }
                options = await SpeakingLanguage.availableOptions()
                downloading = nil
                select(option.identifier)
            } catch {
                downloading = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Copy

extension SpeakingLanguage {

    /// "Hindi (India)", in the reader's language.
    static func displayName(of locale: Locale, in display: Locale = .current) -> String {
        display.localizedString(forIdentifier: locale.identifier(.bcp47)) ?? locale.identifier
    }

    /// The plan's section 3 copy, word for word in English.
    static var explainerCopy: String {
        String(localized: "DailyVox listens in one language at a time. Pick the one you'll speak tonight. This can differ from the app's language.",
               comment: "Settings > Language you speak: the explanation at the top of the screen and under the Settings row.")
    }

    static func downloadCopy(for locale: Locale) -> String {
        String(localized: "\(displayName(of: locale)) needs a one-time download from Apple. After that, everything you say stays on this phone.",
               comment: "Language you speak: before a model download. The placeholder is a language name.")
    }

    static func cannotTranscribeCopy(for locale: Locale) -> String {
        String(localized: "Your phone can't transcribe \(displayName(of: locale)) on-device yet. Your recording is saved, and you can transcribe it later if a model becomes available.",
               comment: "Language you speak: Automatic resolves to a language this iPhone has no on-device model for. The placeholder is a language name.")
    }
}
#endif
