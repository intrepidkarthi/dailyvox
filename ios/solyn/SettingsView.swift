import SwiftUI
import CoreData
import WidgetKit
import DailyVoxTwinEngine
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var reminderManager = ReminderManager.shared
    @ObservedObject private var twinVoice = TwinVoiceService.shared
    @ObservedObject private var lockManager = AppLockManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var goalManager = GoalManager.shared
    @ObservedObject private var bodyTwinManager = BodyTwinManager.shared
    @ObservedObject private var twin = DigitalTwinEngine.shared
    @ObservedObject private var healthKit = HealthKitService.shared
    @ObservedObject private var pendingSnapshots = PendingSnapshotQueue.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: true)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    @State private var showPermissionDeniedAlert = false
    @State private var showShareReceipt = false
    @State private var selectedReminderPreset: String = "evening"

    // Export states
    @State private var showExportSheet = false
    @State private var selectedYear: Int?
    @State private var selectedMonth: Int?
    @State private var selectedExportPeriod: ExportPeriod = .yearly
    @State private var selectedPaperSize: PDFPaperSize = .a4
    @State private var starredOnly: Bool = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    // Author info for PDF export
    @AppStorage("authorName") private var authorName: String = ""
    @AppStorage("authorDescription") private var authorDescription: String = ""
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
    @AppStorage("pilotLabelingEnabled") private var pilotLabelingEnabled: Bool = false

    enum ExportPeriod: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"

        var id: String { rawValue }
    }

    // Storage states
    @State private var audioStorageBytes: Int64 = 0
    @State private var photoStorageBytes: Int64 = 0
    @State private var databaseStorageBytes: Int64 = 0
    @State private var isCalculatingStorage = false
    @State private var showDeleteAudioConfirm = false
    @State private var showDeletePhotosConfirm = false
    @State private var showDeleteAllConfirm = false

    // Health states
    @State private var showWipeHealthConfirm = false
    @State private var isRequestingHealthAccess = false

    // Custom vocabulary
    @ObservedObject private var vocabulary = CustomVocabulary.shared
    @State private var newVocabularyTerm = ""

    // Ambient signals (v1.5.5)
    @ObservedObject private var ambient = AmbientSignalManager.shared
    @ObservedObject private var ambientQueue = PendingAmbientSignalQueue.shared
    @State private var showAmbientReview = false

    // Twin Brain (v1.7 Foundation Models)
    @ObservedObject private var twinBrain = TwinBrainManager.shared

    var body: some View {
        Form {
            // Spec §2.8 puts the Data Shield ledger first: the strongest claim
            // this app makes, itemised, and every line checkable in Android or
            // iOS Settings rather than taken on trust.
            dataShieldSection
            // Daily-use preferences next; PDF export lives with its sibling
            // backup/export tools near the bottom instead of greeting the
            // user with a "Your name" field as the first thing in Settings.
            appearanceSection
            journalingGoalSection
            vocabularySection
            liveActivitiesSection
            securitySection
            dailyReminderSection
            storageSection
            iCloudSection
            healthSection
            ambientSection
            twinBrainSection
            twinVoiceSection
            privacySection
            researchSection
            exportSection
            backupSection
            aboutSection
            #if DEBUG
            developerSection
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor.ignoresSafeArea())
        .onAppear { calculateStorage() }
        .navigationTitle("Settings")
        .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
            #if os(iOS)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            #endif
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable notifications for DailyVox in Settings to receive daily reminders.")
        }
        .alert("Export error", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(item: Binding(
            get: { exportURL.map { IdentifiableURL(url: $0) } },
            set: { if $0 == nil { exportURL = nil } }
        )) { item in
            #if os(iOS)
            ShareSheet(activityItems: [item.url])
            #else
            Text("PDF export is available on iOS.")
            #endif
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var exportSection: some View {
        Section(header: Text("Export"), footer: Text("Your name and description will appear on the cover page of exported PDFs.")) {
            TextField("Your name", text: $authorName)
            TextField("Description (optional)", text: $authorDescription)

            if years.isEmpty {
                Text("No entries to export yet.")
                    .foregroundColor(.secondary)
            } else {
                Picker("Period", selection: $selectedExportPeriod) {
                    ForEach(ExportPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }

                let yearBinding = Binding<Int>(
                    get: { selectedYear ?? years.last ?? Calendar.current.component(.year, from: Date()) },
                    set: { selectedYear = $0 }
                )

                Picker("Year", selection: yearBinding) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }

                if selectedExportPeriod == .monthly {
                    let monthBinding = Binding<Int>(
                        get: { selectedMonth ?? currentMonth },
                        set: { selectedMonth = $0 }
                    )

                    Picker("Month", selection: monthBinding) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthName(month)).tag(month)
                        }
                    }
                } else if selectedExportPeriod == .quarterly {
                    let quarterBinding = Binding<Int>(
                        get: { selectedMonth ?? currentQuarter },
                        set: { selectedMonth = $0 }
                    )

                    Picker("Quarter", selection: quarterBinding) {
                        Text("Q1 (Jan - Mar)").tag(1)
                        Text("Q2 (Apr - Jun)").tag(2)
                        Text("Q3 (Jul - Sep)").tag(3)
                        Text("Q4 (Oct - Dec)").tag(4)
                    }
                }

                Picker("Paper size", selection: $selectedPaperSize) {
                    ForEach(PDFPaperSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }

                Toggle("Only starred entries", isOn: $starredOnly)

                Button {
                    generatePDF()
                } label: {
                    HStack {
                        Text("Export as PDF")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .disabled(isExporting)
            }
        }
    }

    @ViewBuilder
    private var dataShieldSection: some View {
        Section {
            LabeledContent("Network calls made") {
                Text("0 \u{00B7} EVER")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(DS.Palette.sage)
            }
            LabeledContent("Encryption at rest") {
                Text("AES-256")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            Button {
                showShareReceipt = true
            } label: {
                Label("Share this as a receipt", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.goldText)
            }
        } header: {
            Text("Data Shield")
        } footer: {
            Text("The complete permission list: microphone, notifications, speech. No networking code of any kind \u{2014} check it in Settings \u{203A} DailyVox.")
        }
        .sheet(isPresented: $showShareReceipt) {
            ShareSheetView()
        }
    }

    private var appearanceSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 6 : 4), spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeButton(
                        theme: theme,
                        isSelected: themeManager.selectedTheme == theme
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.selectedTheme = theme
                            HapticManager.shared.themeChanged()
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Choose a soft color theme that suits your style.")
        }
    }

    @ViewBuilder
    private var journalingGoalSection: some View {
        Section {
            Toggle("Enable weekly goal", isOn: $goalManager.isEnabled)

            if goalManager.isEnabled {
                Stepper("Target: \(goalManager.weeklyTarget) entries/week", value: $goalManager.weeklyTarget, in: 1...7)

                Toggle("Notify when goal reached", isOn: $goalManager.notifyOnGoal)
            }
        } header: {
            Text("Journaling Goal")
        } footer: {
            Text("Set a weekly journaling target to build a consistent habit.")
        }
    }

    private var vocabularySection: some View {
        Section {
            HStack {
                TextField("Add a name or word", text: $newVocabularyTerm)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onSubmit(addVocabularyTerm)
                Button(action: addVocabularyTerm) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newVocabularyTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(vocabulary.terms, id: \.self) { term in
                Text(term)
            }
            .onDelete { vocabulary.remove(at: $0) }
        } header: {
            Text("Spoken Words")
        } footer: {
            Text("Names and uncommon words that transcription keeps getting wrong — like a child's name. DailyVox will listen for these on every recording, so a correction sticks instead of coming back wrong. Stays on this iPhone.")
        }
    }

    private func addVocabularyTerm() {
        let term = newVocabularyTerm
        newVocabularyTerm = ""
        vocabulary.add(term)
    }

    private var ambientSection: some View {
        Section {
            Toggle("Photo context", isOn: Binding(
                get: { ambient.photoSignalsEnabled },
                set: { newValue in
                    if newValue {
                        Task { _ = await ambient.enablePhotoSignals() }
                    } else {
                        ambient.photoSignalsEnabled = false
                    }
                }
            ))
            Toggle("Music mood", isOn: Binding(
                get: { ambient.musicSignalsEnabled },
                set: { newValue in
                    if newValue {
                        Task { _ = await ambient.enableMusicSignals() }
                    } else {
                        ambient.musicSignalsEnabled = false
                    }
                }
            ))
            if ambientQueue.count > 0 {
                Button {
                    showAmbientReview = true
                } label: {
                    HStack {
                        Text("Review waiting signals")
                        Spacer()
                        Text("\(ambientQueue.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Your Day (Ambient)")
        } footer: {
            Text("On-device only. DailyVox reads the kind of photos you took and the music you reached for, turns them into a one-line note, and holds it for you to keep or let go — nothing reaches your Twin until you say so. Only derived labels are ever produced; your photos and audio never leave this iPhone. Off by default.")
        }
        .sheet(isPresented: $showAmbientReview) {
            AmbientReviewView()
        }
    }

    // MARK: - Twin Brain (v1.7 Foundation Models)

    /// Absent entirely on iOS < 26 and on hardware that can't run Apple
    /// Intelligence — no dead toggle to explain (healthSection pattern).
    /// Default ON where available: this gates no new permission or data flow;
    /// Read replies aloud using an installed system voice. Personal Voice is deliberately not
    /// used: it carries the user's real accent but costs a ~30-minute enrollment the app cannot
    /// do for them, so this ships with voices already on the device and asks nothing.
    @ViewBuilder
    private var twinVoiceSection: some View {
        Section {
            Toggle("Read replies aloud", isOn: $twinVoice.isEnabled)

            if twinVoice.isEnabled {
                Picker("Voice", selection: $twinVoice.voiceIdentifier) {
                    Text("Match my region").tag("")
                    ForEach(twinVoice.availableVoices, id: \.identifier) { v in
                        Text(twinVoice.label(for: v)).tag(v.identifier)
                    }
                }

                Button {
                    twinVoice.isSpeaking ? twinVoice.stop() : twinVoice.preview()
                } label: {
                    Label(twinVoice.isSpeaking ? "Stop" : "Hear a sample",
                          systemImage: twinVoice.isSpeaking ? "stop.circle" : "play.circle")
                        .font(.caption)
                }
            }
        } header: {
            Text("Twin Voice")
        } footer: {
            Text("Your Twin can read its replies out loud using a voice already on this iPhone. Pick a regional voice if it sounds closer to you — synthesis happens on this device and nothing is uploaded. Off by default.")
        }
    }

    /// the toggle is a kill-switch back to the classic template chat.
    @ViewBuilder
    private var twinBrainSection: some View {
        if twinBrain.isSupportedHere {
            Section {
                Toggle("Conversational answers", isOn: $twinBrain.enabled)

                switch twinBrain.status {
                case .modelNotReady:
                    Label("Apple Intelligence is still preparing the on-device model — DailyVox switches automatically when it's ready.",
                          systemImage: "hourglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                case .appleIntelligenceOff:
                    #if os(iOS)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Turn on Apple Intelligence in Settings", systemImage: "gear")
                            .font(.caption)
                    }
                    #endif
                default:
                    EmptyView()
                }
            } header: {
                Text("Twin Brain")
            } footer: {
                Text("Ask Your Twin answers in your own words, grounded in your entries and citing the ones it drew from. Runs entirely on this iPhone with Apple's on-device model — zero network calls, nothing leaves the device. Turning it off keeps free-text questions working through journal search, without the conversational model.")
            }
        }
    }

    @ViewBuilder
    private var liveActivitiesSection: some View {
        Section {
            Toggle("Show streak in Dynamic Island", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: kStreakLiveActivityEnabledKey) },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: kStreakLiveActivityEnabledKey)
                    Task { @MainActor in
                        if newValue {
                            let streak = currentStreak(in: viewContext)
                            let total = totalEntryCount(in: viewContext)
                            let hasToday = streak > 0 && hasEntryToday(in: viewContext)
                            LiveActivityManager.shared.refreshStreakActivity(
                                streak: streak,
                                hasEntryToday: hasToday,
                                totalEntries: total
                            )
                        } else {
                            LiveActivityManager.shared.endStreakActivity()
                        }
                    }
                }
            ))
        } header: {
            Text("Live Activities")
        } footer: {
            Text("Pin your current journaling streak to the Dynamic Island and Lock Screen. The recording timer and new-star celebration appear automatically when you record.")
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Section(header: Text("Security")) {
            Toggle("Enable Face ID", isOn: $lockManager.isEnabled)

            if lockManager.isEnabled {
                Text("DailyVox will require \(lockManager.biometryTypeName) or your device passcode to open.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !lockManager.biometricsAvailable {
                Text("Your device will use your passcode to unlock DailyVox.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var dailyReminderSection: some View {
        Section {
            Toggle("Remind me to record", isOn: Binding(
                get: { reminderManager.isEnabled },
                set: { newValue in
                    if newValue {
                        reminderManager.requestPermissionIfNeeded { granted in
                            if granted {
                                reminderManager.isEnabled = true
                            } else {
                                showPermissionDeniedAlert = true
                            }
                        }
                    } else {
                        reminderManager.isEnabled = false
                    }
                }
            ))

            if reminderManager.isEnabled {
                ReminderPresetRow(
                    icon: "sunrise",
                    title: "Morning",
                    time: "7:00 AM",
                    intent: "Start your day with clarity",
                    isSelected: selectedReminderPreset == "morning"
                ) {
                    selectedReminderPreset = "morning"
                    applyReminderPreset(hour: 7, minute: 0)
                }

                ReminderPresetRow(
                    icon: "sun.max",
                    title: "Midday",
                    time: "12:30 PM",
                    intent: "Reset and reflect",
                    isSelected: selectedReminderPreset == "midday"
                ) {
                    selectedReminderPreset = "midday"
                    applyReminderPreset(hour: 12, minute: 30)
                }

                ReminderPresetRow(
                    icon: "moon.stars",
                    title: "Evening",
                    time: "8:00 PM",
                    intent: "Unwind and look back",
                    isSelected: selectedReminderPreset == "evening"
                ) {
                    selectedReminderPreset = "evening"
                    applyReminderPreset(hour: 20, minute: 0)
                }

                ReminderPresetRow(
                    icon: "slider.horizontal.3",
                    title: "Custom",
                    time: nil,
                    intent: "Pick your own time",
                    isSelected: selectedReminderPreset == "custom"
                ) {
                    selectedReminderPreset = "custom"
                }

                if selectedReminderPreset == "custom" {
                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: { reminderManager.reminderTime },
                            set: { reminderManager.reminderTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        } header: {
            Text("Daily Reminder")
        } footer: {
            Text("DailyVox sends one gentle notification each day at your chosen time.")
        }
    }

    private func applyReminderPreset(hour: Int, minute: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderManager.reminderTime)
        components.hour = hour
        components.minute = minute
        components.second = 0
        if let date = Calendar.current.date(from: components) {
            reminderManager.reminderTime = date
        }
    }

    @ViewBuilder
    private var iCloudSection: some View {
        Section {
            Toggle(isOn: $iCloudSyncEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(iCloudSyncEnabled && PersistenceController.isCloudAvailable ? DS.Palette.sage.opacity(0.15) : DS.Palette.inkMute.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: iCloudSyncEnabled && PersistenceController.isCloudAvailable ? "icloud.fill" : "icloud.slash")
                            .font(.body)
                            .foregroundColor(iCloudSyncEnabled && PersistenceController.isCloudAvailable ? DS.Palette.sage : DS.Palette.inkMute)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Sync")
                            .font(.subheadline.weight(.semibold))
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: iCloudSyncEnabled) { _, newValue in
                PersistenceController.shared.setCloudSyncEnabled(newValue)
            }

            if iCloudSyncEnabled && PersistenceController.isCloudAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DS.Palette.forest)
                            .font(.caption)
                        Text("Entries sync automatically via your personal iCloud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(DS.Palette.forest)
                            .font(.caption)
                        Text("End-to-end encrypted with your Apple ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("iCloud Sync")
        } footer: {
            Text(iCloudSyncEnabled
                 ? (PersistenceController.isCloudAvailable
                    ? "Your data syncs securely through your personal iCloud account. Only you can access it."
                    : "Sign in to iCloud in iOS Settings to enable sync.")
                 : "Sync is off. Your entries are stored only on this device.")
        }
    }

    private var syncStatusText: String {
        if !iCloudSyncEnabled {
            return "Off — entries stay on this device only"
        }
        if PersistenceController.isCloudAvailable {
            return "Syncing across your devices"
        }
        return "iCloud not available — sign in to enable"
    }

    @ViewBuilder
    private var healthSection: some View {
        // Absent entirely on devices without HealthKit — no dead toggle to explain.
        if healthKit.isAvailable {
            Section {
                Toggle(isOn: Binding(
                    // Optimistic while the async enable flow runs: isActive
                    // only flips after the Health sheet completes, so without
                    // this the knob the user just flipped ON snaps back to
                    // OFF for the whole permission ask. It reverts naturally
                    // if requestAuthorization throws (flag resets, get falls
                    // back to isActive == false).
                    get: { isRequestingHealthAccess || twin.bodyTwin.isActive },
                    set: { newValue in
                        if newValue {
                            enableBodyTwin()
                        } else {
                            bodyTwinManager.isEnabled = false
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(twin.bodyTwin.isActive ? DS.Palette.terracotta.opacity(0.15) : DS.Palette.inkMute.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "figure.mind.and.body")
                                .font(.body)
                                .foregroundColor(twin.bodyTwin.isActive ? DS.Palette.terracotta : DS.Palette.inkMute)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Body Twin")
                                .font(.subheadline.weight(.semibold))
                            Text(bodyTwinStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(isRequestingHealthAccess)

                if twin.bodyTwin.isActive {
                    HealthSignalToggle(
                        label: "Sleep",
                        detail: "Hours of rest the night before",
                        icon: "moon.zzz.fill",
                        color: DS.Palette.sage,
                        isOn: $bodyTwinManager.sleepEnabled
                    )
                    HealthSignalToggle(
                        label: "Heart",
                        detail: "Morning HRV and resting heart rate",
                        icon: "heart.fill",
                        color: DS.Palette.terracotta,
                        isOn: heartSignalBinding
                    )
                    HealthSignalToggle(
                        label: "Steps",
                        detail: "Steps taken through the day",
                        icon: "figure.walk",
                        color: DS.Palette.gold,
                        isOn: $bodyTwinManager.stepsEnabled
                    )
                    HealthSignalToggle(
                        label: "Mindful Minutes",
                        detail: "Quiet minutes you set aside",
                        icon: "leaf.fill",
                        color: DS.Palette.forest,
                        isOn: $bodyTwinManager.mindfulEnabled
                    )
                }

                if pendingSnapshots.count > 0 {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DS.Palette.gold.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "sparkles")
                                .font(.body)
                                .foregroundColor(DS.Palette.gold)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pendingSnapshots.count == 1
                                 ? "1 signal waiting for review"
                                 : "\(pendingSnapshots.count) signals waiting for review")
                                .font(.subheadline.weight(.semibold))
                            // The Twin tab opens the queue even while Body
                            // Twin is off (BodyTwinCard) — the caption tracks
                            // that so it never points at a door that won't open.
                            Text(twin.bodyTwin.isActive
                                 ? "Your Twin tab holds them — nothing is learned until you tap Keep."
                                 : "Body Twin is off, but the Twin tab still holds them — Keep or Let go anytime.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button(role: .destructive) {
                    showWipeHealthConfirm = true
                } label: {
                    Label("Wipe All Health Snapshots", systemImage: "trash")
                }
            } header: {
                Text("Health")
            } footer: {
                // Honest promise: DECISIONS #1's single sanctioned exit path
                // (user-initiated encrypted export, user-held key) is named,
                // so "stays on this iPhone" never over-claims.
                Text("Health signals stay on this iPhone — never synced, and your Twin only learns the ones you approve. The one way they ever leave is inside an encrypted backup you export yourself, locked with your password.")
            }
            .confirmationDialog("Wipe all health snapshots and everything your Twin learned from them? This cannot be undone.",
                                isPresented: $showWipeHealthConfirm, titleVisibility: .visible) {
                Button("Wipe Health Snapshots", role: .destructive) { wipeAllHealthSnapshots() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var bodyTwinStatusText: String {
        if isRequestingHealthAccess {
            return "Asking Health for permission…"
        }
        return twin.bodyTwin.isActive
            ? "Learning what your body felt"
            : "Off — your Twin learns from your words alone"
    }

    /// One switch for both heart signals — HRV and resting rate travel together.
    private var heartSignalBinding: Binding<Bool> {
        Binding(
            get: { bodyTwinManager.hrvEnabled && bodyTwinManager.restingHREnabled },
            set: { newValue in
                bodyTwinManager.hrvEnabled = newValue
                bodyTwinManager.restingHREnabled = newValue
            }
        )
    }

    /// Master-toggle ON path. First time through, this shows Apple's Health
    /// permission sheet; the sheet completing is all read-only HealthKit lets
    /// us know (per-signal grants are invisible by design), so completion
    /// counts as "asked" and the Twin turns on.
    private func enableBodyTwin() {
        guard !isRequestingHealthAccess else { return }
        isRequestingHealthAccess = true
        Task { @MainActor in
            defer { isRequestingHealthAccess = false }
            if !healthKit.isAuthorized {
                do {
                    try await healthKit.requestAuthorization()
                } catch {
                    return // sheet failed to appear — leave the toggle off
                }
            }
            bodyTwinManager.recordAuthorizationRequested()
            bodyTwinManager.isEnabled = true
            // Prime the Motion & Fitness prompt HERE, inside the moment the
            // user chose to connect — the first CMMotionActivity query is
            // what triggers it, and without this pass it would otherwise pop
            // un-contextualized in the middle of their next entry save.
            await ActivityContextDetector.shared.update()
        }
    }

    private func wipeAllHealthSnapshots() {
        bodyTwinManager.wipeAllHealthData()
        HapticManager.shared.entryDeleted()
    }

    @ViewBuilder
    private var privacySection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(DS.Palette.forest.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundColor(DS.Palette.forest)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy First")
                        .font(.subheadline.weight(.semibold))
                    Text("Your data is encrypted and private")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                PrivacyInfoRow(
                    icon: "waveform",
                    title: "On-Device Transcription",
                    description: "Voice converted to text using Apple's speech recognition"
                )
                PrivacyInfoRow(
                    icon: "server.rack",
                    title: "No Third-Party Servers",
                    description: "We never send your data to our servers"
                )
                PrivacyInfoRow(
                    icon: "person.fill.xmark",
                    title: "No Account Required",
                    description: "No sign-up, no tracking, no analytics"
                )
            }
            .padding(.vertical, 8)
        } header: {
            Text("Privacy & Security")
        } footer: {
            Text("Your thoughts are yours alone. Data syncs only through your personal iCloud, encrypted with your Apple ID.")
        }
    }

    // A display-only invitation: the app collects nothing, so research
    // recruitment inverts — the invitation stands here, and joining is a
    // choice the user makes in their browser, never a call the app makes.
    private var researchSection: some View {
        Section {
            Link(destination: URL(string: "https://getdailyvox.com/research")!) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(DS.Palette.gold.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "testtube.2")
                            .font(.title3)
                            .foregroundColor(DS.Palette.gold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Join the research pilot")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("Help measure how well the Twin knows you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Toggle(isOn: $pilotLabelingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Label my entries after recording")
                        .font(.subheadline.weight(.semibold))
                    Text("For pilot participants — a one-tap feeling check after each recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(DS.Palette.gold)

            if pilotLabelingEnabled {
                Button {
                    exportResearchData()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(DS.Palette.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export research data")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Text("Your labeled entries as JSON — you choose where it goes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } footer: {
            Text("Opens getdailyvox.com. Taking part is voluntary and consented; nothing about your journal is collected or transmitted by the app. Self-labels stay on this phone until you export and share them yourself, under the pilot consent covering research and model-training use.")
        }
    }

    private func exportResearchData() {
        do {
            // Device AI availability rides the export per the research
            // protocol (NLEmbedding/OS version skew is an analysis variable).
            let aiAvailable = TwinBrainManager.shared.status == .ready
            exportURL = try BackupService.shared.exportResearchJSON(
                entries: Array(entries),
                appleIntelligenceAvailable: aiAvailable
            )
        } catch {
            exportError = "Research export failed: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private var backupSection: some View {
        Section {
            NavigationLink {
                BackupExportView(entries: Array(entries))
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(DS.Palette.terracotta.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(DS.Palette.terracotta)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Data")
                            .font(.subheadline.weight(.semibold))
                        Text("JSON, Text, Markdown, CSV")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            NavigationLink {
                ImportBackupView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(DS.Palette.sage.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "square.and.arrow.down")
                            .font(.subheadline)
                            .foregroundColor(DS.Palette.sage)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Backup")
                            .font(.subheadline.weight(.semibold))
                        Text("Restore from JSON backup")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Backup & Export")
        } footer: {
            Text("Export your diary for safekeeping or import a previous backup.")
        }
    }

    @ViewBuilder
    private var storageSection: some View {
        Section {
            if isCalculatingStorage {
                HStack {
                    Text("Calculating...")
                    Spacer()
                    ProgressView()
                }
            } else {
                StorageRow(label: "Audio Recordings", bytes: audioStorageBytes, icon: "waveform", color: DS.Palette.sage)
                StorageRow(label: "Photos", bytes: photoStorageBytes, icon: "photo", color: DS.Palette.terracotta)
                StorageRow(label: "Database", bytes: databaseStorageBytes, icon: "cylinder", color: DS.Palette.gold)

                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formatBytes(audioStorageBytes + photoStorageBytes + databaseStorageBytes))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Button(role: .destructive) {
                    showDeleteAudioConfirm = true
                } label: {
                    Label("Clear Audio Recordings", systemImage: "waveform.slash")
                }
                .disabled(audioStorageBytes == 0)

                Button(role: .destructive) {
                    showDeletePhotosConfirm = true
                } label: {
                    Label("Clear Photos", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(photoStorageBytes == 0)

                Button(role: .destructive) {
                    showDeleteAllConfirm = true
                } label: {
                    Label("Delete All Entries & Media", systemImage: "trash")
                }
            }
        } header: {
            HStack {
                Text("Storage")
                Spacer()
                Button {
                    calculateStorage()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
        } footer: {
            Text("Audio and photos are stored on-device only. iCloud syncs text entries only.")
        }
        .confirmationDialog("Delete all audio recordings? Your text entries are kept.",
                            isPresented: $showDeleteAudioConfirm, titleVisibility: .visible) {
            Button("Delete Audio", role: .destructive) { deleteAllAudio() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete all photos? Your text entries are kept.",
                            isPresented: $showDeletePhotosConfirm, titleVisibility: .visible) {
            Button("Delete Photos", role: .destructive) { deleteAllPhotos() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete ALL entries and media? This cannot be undone.",
                            isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Storage Deletion

    private func deleteAllAudio() {
        Self.clearDirectory(name: "Recordings")
        HapticManager.shared.entryDeleted()
        calculateStorage()
    }

    private func deleteAllPhotos() {
        Self.clearDirectory(name: "Photos")
        HapticManager.shared.entryDeleted()
        calculateStorage()
    }

    /// Deletes every entry (propagating to iCloud) plus all on-device media.
    private func deleteAllData() {
        let fetch: NSFetchRequest<DiaryEntry> = DiaryEntry.fetchRequest()
        if let all = try? viewContext.fetch(fetch) {
            let deletedIds = all.compactMap { $0.id }
            for entry in all { viewContext.delete(entry) }
            try? viewContext.save()
            // "Delete all data" has to mean the derived indexes too, or search
            // and the entity graph keep answering from entries that are gone.
            for id in deletedIds {
                SemanticSearchManager.shared.removeEntry(id: id)
                DigitalTwinEngine.shared.forgetEntry(id.uuidString)
            }
        }
        Self.clearDirectory(name: "Recordings")
        Self.clearDirectory(name: "Photos")
        HapticManager.shared.entryDeleted()
        WidgetCenter.shared.reloadAllTimelines()
        calculateStorage()
    }

    private static func clearDirectory(name: String) {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let dir = base.appendingPathComponent(name)
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files { try? fm.removeItem(at: file) }
    }

    private func calculateStorage() {
        isCalculatingStorage = true
        DispatchQueue.global(qos: .userInitiated).async {
            let audioBytes = Self.directorySize(name: "Recordings")
            let photoBytes = Self.directorySize(name: "Photos")
            let dbBytes = Self.databaseSize()

            DispatchQueue.main.async {
                audioStorageBytes = audioBytes
                photoStorageBytes = photoBytes
                databaseStorageBytes = dbBytes
                isCalculatingStorage = false
            }
        }
    }

    private static func directorySize(name: String) -> Int64 {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }
        let dir = base.appendingPathComponent(name)
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    private static func databaseSize() -> Int64 {
        let fm = FileManager.default
        let possiblePaths: [URL] = [
            fm.containerURL(forSecurityApplicationGroupIdentifier: PersistenceController.appGroupIdentifier)?
                .appendingPathComponent("solyn.sqlite"),
            NSPersistentCloudKitContainer.defaultDirectoryURL()
                .appendingPathComponent("solyn.sqlite")
        ].compactMap { $0 }

        for path in possiblePaths {
            // sqlite has companion -wal and -shm files
            let extensions = ["", "-wal", "-shm"]
            let total = extensions.reduce(Int64(0)) { sum, ext in
                let file = URL(fileURLWithPath: path.path + ext)
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return sum + Int64(size)
            }
            if total > 0 { return total }
        }
        return 0
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Total Entries")
                Spacer()
                Text("\(totalEntriesCount)")
                    .foregroundColor(.secondary)
            }

            Button {
                HapticManager.shared.buttonTap()
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Replay welcome")
                }
            }
        }
    }

    #if DEBUG
    /// Development instruments. Compiled out of Release entirely — this section
    /// and everything it reaches cannot ship.
    private var developerSection: some View {
        Section {
            NavigationLink {
                MemoryProbeView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "memorychip")
                        .font(.subheadline)
                        .foregroundColor(DS.Palette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory probe")
                            .font(.subheadline.weight(.semibold))
                        Text("Measure what a workload costs this process")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Debug builds only. Gates the v1.10 on-device voice work: a candidate model ships on a measured peak footprint, never a projected one.")
        }
    }
    #endif

    private var totalEntriesCount: Int {
        let fetchRequest = DiaryEntry.fetchRequest() as NSFetchRequest<NSFetchRequestResult>
        return (try? viewContext.count(for: fetchRequest)) ?? entries.count
    }

    private var years: [Int] {
        let calendar = Calendar.current
        let allYears = entries.compactMap { entry -> Int? in
            guard let date = entry.date else { return nil }
            return calendar.component(.year, from: date)
        }
        return Array(Set(allYears)).sorted()
    }

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    private var currentQuarter: Int {
        (Calendar.current.component(.month, from: Date()) - 1) / 3 + 1
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return ""
    }

    private func generatePDF() {
        #if os(iOS)
        let year = selectedYear ?? years.last!
        isExporting = true

        // Determine date range based on export period
        let dateRange: PDFExportService.DateRange
        let periodTitle: String

        switch selectedExportPeriod {
        case .monthly:
            let month = selectedMonth ?? currentMonth
            dateRange = .month(year: year, month: month)
            periodTitle = "\(monthName(month)) \(year)"
        case .quarterly:
            let quarter = selectedMonth ?? currentQuarter
            dateRange = .quarter(year: year, quarter: quarter)
            periodTitle = "Q\(quarter) \(year)"
        case .yearly:
            dateRange = .year(year)
            periodTitle = String(year)
        }

        Task {
            do {
                let baseEntries: [DiaryEntry]
                if starredOnly {
                    baseEntries = entries.filter { $0.isStarred }
                } else {
                    baseEntries = Array(entries)
                }

                let url = try PDFExportService.generatePDF(
                    for: baseEntries,
                    dateRange: dateRange,
                    periodTitle: periodTitle,
                    paperSize: selectedPaperSize,
                    authorName: authorName.isEmpty ? nil : authorName,
                    authorDescription: authorDescription.isEmpty ? nil : authorDescription
                )
                await MainActor.run {
                    exportURL = url
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
        #else
        exportError = "PDF export is available on iOS."
        #endif
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Theme Button

struct ThemeButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: theme.icon)
                        .font(.system(.subheadline).weight(.medium))
                        .foregroundColor(.white)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(theme.accentColor, lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                }
                
                Text(theme.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? theme.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Storage Row

struct StorageRow: View {
    let label: String
    let bytes: Int64
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            Text(label)
            Spacer()
            Text(formattedSize)
                .foregroundColor(.secondary)
        }
    }

    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Reminder Preset Row

struct ReminderPresetRow: View {
    let icon: String
    let title: String
    let time: String?
    let intent: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DS.Palette.sage.opacity(0.16) : DS.Palette.inkMute.opacity(0.10))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(.subheadline).weight(.semibold))
                        .foregroundColor(isSelected ? DS.Palette.sage : DS.Palette.inkMute)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.dsHeadline)
                            .foregroundColor(DS.Palette.ink)
                        if let time = time {
                            Text(time)
                                .font(.dsCaption)
                                .foregroundColor(DS.Palette.inkMute)
                        }
                    }
                    Text(intent)
                        .font(.dsCaption)
                        .foregroundColor(DS.Palette.inkMute)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(.body))
                    .foregroundColor(isSelected ? DS.Palette.sage : DS.Palette.inkMute.opacity(0.4))
            }
            .padding(.vertical, DS.Space.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? DS.Palette.sage.opacity(0.08) : Color.clear)
    }
}

// MARK: - Health Signal Toggle

struct HealthSignalToggle: View {
    let label: String
    let detail: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Privacy Info Row

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(DS.Palette.forest)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
