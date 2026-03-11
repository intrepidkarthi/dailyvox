import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var reminderManager = ReminderManager.shared
    @ObservedObject private var lockManager = AppLockManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var goalManager = GoalManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: true)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    @State private var showPermissionDeniedAlert = false

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

    var body: some View {
        Form {
            exportSection
            appearanceSection
            journalingGoalSection
            securitySection
            dailyReminderSection
            storageSection
            iCloudSection
            privacySection
            backupSection
            aboutSection
        }
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
    private var appearanceSection: some View {
        Section {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
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

    @ViewBuilder
    private var securitySection: some View {
        Section(header: Text("Security")) {
            Toggle("Enable Face ID", isOn: $lockManager.isEnabled)

            if lockManager.isEnabled {
                Text("DailyVox will require \\(lockManager.biometryTypeName) or your device passcode to open.")
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
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: { reminderManager.reminderTime },
                        set: { reminderManager.reminderTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("Daily Reminder")
        } footer: {
            Text("DailyVox sends one gentle notification each day at your chosen time.")
        }
    }

    @ViewBuilder
    private var iCloudSection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PersistenceController.isCloudAvailable ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: PersistenceController.isCloudAvailable ? "icloud.fill" : "icloud.slash")
                        .font(.title3)
                        .foregroundColor(PersistenceController.isCloudAvailable ? .blue : .gray)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(PersistenceController.isCloudAvailable ? "iCloud Sync Active" : "iCloud Not Available")
                        .font(.subheadline.weight(.semibold))
                    Text(PersistenceController.isCloudAvailable
                         ? "Your entries sync across all your devices"
                         : "Sign in to iCloud in Settings to enable sync")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)

            if PersistenceController.isCloudAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Entries sync automatically via your personal iCloud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
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
            Text(PersistenceController.isCloudAvailable
                 ? "Your data syncs securely through your personal iCloud account. Only you can access it."
                 : "Enable iCloud to sync your diary across iPhone, iPad, and Mac.")
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundColor(.green)
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

    @ViewBuilder
    private var backupSection: some View {
        Section {
            NavigationLink {
                BackupExportView(entries: Array(entries))
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Data")
                            .font(.subheadline)
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
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "square.and.arrow.down")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Backup")
                            .font(.subheadline)
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
                StorageRow(label: "Audio Recordings", bytes: audioStorageBytes, icon: "waveform", color: .blue)
                StorageRow(label: "Photos", bytes: photoStorageBytes, icon: "photo", color: .pink)
                StorageRow(label: "Database", bytes: databaseStorageBytes, icon: "cylinder", color: .orange)

                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formatBytes(audioStorageBytes + photoStorageBytes + databaseStorageBytes))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
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
        }
    }

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
                        .font(.system(size: 14, weight: .medium))
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

// MARK: - Privacy Info Row

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.green)
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
