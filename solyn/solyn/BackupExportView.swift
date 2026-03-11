//
//  BackupExportView.swift
//  solyn
//
//  View for exporting diary data in various formats.
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupExportView: View {
    let entries: [DiaryEntry]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .json
    @State private var includeAllEntries = true
    @State private var starredOnly = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var encryptionPassword = ""
    @State private var confirmPassword = ""
    
    private var filteredEntryCount: Int {
        // JSON is always a full backup – filters apply only to other formats
        if selectedFormat == .json || selectedFormat == .encryptedBackup {
            return entries.count
        }
        
        var filtered = entries
        
        if !includeAllEntries {
            filtered = filtered.filter { entry in
                guard let date = entry.date else { return false }
                return date >= startDate && date <= endDate
            }
        }
        
        if starredOnly {
            filtered = filtered.filter { $0.isStarred }
        }
        
        return filtered.count
    }
    
    var body: some View {
        Form {
            // Format selection
            Section {
                ForEach(ExportFormat.allCases.filter { $0 != .pdf }, id: \.self) { format in
                    Button {
                        selectedFormat = format
                        HapticManager.shared.selectionChanged()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(selectedFormat == format ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
                                    .frame(width: 40, height: 40)
                                Image(systemName: format.icon)
                                    .foregroundColor(selectedFormat == format ? .accentColor : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text(format.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedFormat == format {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Export Format")
            }
            
            // Date range / filters (for non-JSON formats)
            Section {
                Toggle("Include all entries", isOn: $includeAllEntries)
                
                if !includeAllEntries {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }
                
                Toggle("Starred entries only", isOn: $starredOnly)
            } header: {
                Text("Filter")
            } footer: {
                if selectedFormat == .json {
                    Text("JSON backup always includes all entries")
                } else {
                    Text("\(filteredEntryCount) entries will be exported")
                }
            }
            .disabled(selectedFormat == .json || selectedFormat == .encryptedBackup)

            // Password fields for encrypted backup
            if selectedFormat == .encryptedBackup {
                Section {
                    SecureField("Password", text: $encryptionPassword)
                    SecureField("Confirm Password", text: $confirmPassword)

                    if !encryptionPassword.isEmpty && !confirmPassword.isEmpty && encryptionPassword != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Encryption Password")
                } footer: {
                    Text("Choose a strong password. You'll need it to restore this backup. There is no way to recover a forgotten password.")
                }
            }

            // Export info
            Section {
                if selectedFormat == .json || selectedFormat == .encryptedBackup {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Can be imported back into DailyVox")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if selectedFormat == .encryptedBackup {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("AES-256 encrypted with your password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("File saved to your device only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Info")
            }
            
            // Export button
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(isExporting ? "Exporting..." : "Export \(filteredEntryCount) Entries")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(isExporting || filteredEntryCount == 0 || (selectedFormat == .encryptedBackup && (encryptionPassword.isEmpty || encryptionPassword != confirmPassword)))
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(item: Binding(
            get: { exportURL.map { IdentifiableURL(url: $0) } },
            set: { if $0 == nil { exportURL = nil } }
        )) { item in
            ShareSheet(activityItems: [item.url])
        }
    }
    
    private func exportData() {
        isExporting = true
        HapticManager.shared.buttonTap()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url: URL
                
                switch selectedFormat {
                case .json:
                    url = try BackupService.shared.exportToJSON(entries: entries)
                case .encryptedBackup:
                    url = try BackupService.shared.exportEncrypted(entries: entries, password: encryptionPassword)
                case .text, .markdown, .csv:
                    var filteredEntries = entries
                    
                    if !includeAllEntries {
                        filteredEntries = filteredEntries.filter { entry in
                            guard let date = entry.date else { return false }
                            return date >= startDate && date <= endDate
                        }
                    }
                    
                    if starredOnly {
                        filteredEntries = filteredEntries.filter { $0.isStarred }
                    }
                    
                    switch selectedFormat {
                    case .text:
                        url = try BackupService.shared.exportToText(entries: filteredEntries)
                    case .markdown:
                        url = try BackupService.shared.exportToMarkdown(entries: filteredEntries)
                    case .csv:
                        url = try BackupService.shared.exportToCSV(entries: filteredEntries)
                    default:
                        // Should not be reached
                        return
                    }
                case .pdf:
                    // PDF handled separately elsewhere
                    return
                }
                
                DispatchQueue.main.async {
                    isExporting = false
                    exportURL = url
                    HapticManager.shared.entrySaved()
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Import Backup View

struct ImportBackupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var showResult = false
    @State private var pendingEncryptedURL: URL?
    @State private var showPasswordPrompt = false
    @State private var importPassword = ""

    enum ImportResult {
        case success(Int)
        case error(String)
    }
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Import JSON Backup")
                        .font(.headline)
                    
                    Text("Select a JSON backup file exported from DailyVox to restore your entries.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Duplicate entries are automatically skipped")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Existing entries are preserved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text("Imported entries sync to iCloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("How it works")
            }
            
            Section {
                Button {
                    showFilePicker = true
                    HapticManager.shared.buttonTap()
                } label: {
                    HStack {
                        Spacer()
                        if isImporting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(isImporting ? "Importing..." : "Select Backup File")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(isImporting)
            }
        }
        .navigationTitle("Import Backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.json, UTType(filenameExtension: "dvx") ?? UTType.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showPasswordPrompt) {
            NavigationView {
                Form {
                    Section {
                        SecureField("Password", text: $importPassword)
                    } header: {
                        Text("Enter Backup Password")
                    } footer: {
                        Text("Enter the password you used when creating this encrypted backup.")
                    }

                    Section {
                        Button("Decrypt & Import") {
                            showPasswordPrompt = false
                            if let url = pendingEncryptedURL {
                                importEncryptedBackup(from: url)
                            }
                        }
                        .disabled(importPassword.isEmpty)
                    }
                }
                .navigationTitle("Encrypted Backup")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showPasswordPrompt = false
                            pendingEncryptedURL?.stopAccessingSecurityScopedResource()
                            pendingEncryptedURL = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Import Complete", isPresented: $showResult) {
            Button("OK") {
                if case .success = importResult {
                    dismiss()
                }
            }
        } message: {
            switch importResult {
            case .success(let count):
                Text("Successfully imported \(count) new entries.")
            case .error(let message):
                Text(message)
            case .none:
                Text("")
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if url.pathExtension.lowercased() == "dvx" {
                // Encrypted backup — prompt for password
                _ = url.startAccessingSecurityScopedResource()
                pendingEncryptedURL = url
                importPassword = ""
                showPasswordPrompt = true
            } else {
                importBackup(from: url)
            }
        case .failure(let error):
            importResult = .error(error.localizedDescription)
            showResult = true
        }
    }

    private func importEncryptedBackup(from url: URL) {
        isImporting = true
        defer { url.stopAccessingSecurityScopedResource() }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try BackupService.shared.importEncrypted(url: url, password: importPassword, context: viewContext)
                DispatchQueue.main.async {
                    isImporting = false
                    importResult = .success(count)
                    showResult = true
                    HapticManager.shared.entrySaved()
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    importResult = .error("Failed to import: \(error.localizedDescription)")
                    showResult = true
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func importBackup(from url: URL) {
        isImporting = true
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            importResult = .error("Unable to access the selected file.")
            showResult = true
            isImporting = false
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try BackupService.shared.importFromJSON(url: url, context: viewContext)
                
                DispatchQueue.main.async {
                    isImporting = false
                    importResult = .success(count)
                    showResult = true
                    HapticManager.shared.entrySaved()
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    importResult = .error("Failed to import: \(error.localizedDescription)")
                    showResult = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        BackupExportView(entries: [])
    }
}
