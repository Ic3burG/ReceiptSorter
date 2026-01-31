import SwiftUI
import ReceiptSorterCore

struct ModernSettingsView: View {
    @State private var selectedSection: SettingsSection? = .general
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case export = "Export"
        case organization = "Organization"
        case cloudSync = "Cloud Sync"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .export: return "doc.badge.arrow.up"
            case .organization: return "folder.badge.gearshape"
            case .cloudSync: return "cloud"
            }
        }
        
        var color: Color {
            switch self {
            case .general: return .blue
            case .export: return .green
            case .organization: return .orange
            case .cloudSync: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label {
                    Text(section.rawValue)
                } icon: {
                    Image(systemName: section.icon)
                        .foregroundColor(section.color)
                }
                .tag(section)
            }
            .navigationTitle("Settings")
            .frame(minWidth: 200)
        } detail: {
            // Detail view
            if let section = selectedSection {
                settingsDetailView(for: section)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                Text("Select a settings category")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 800, height: 600)
    }
    
    @ViewBuilder
    private func settingsDetailView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsDetailView()
        case .export:
            ExportSettingsDetailView()
        case .organization:
            OrganizationSettingsDetailView()
        case .cloudSync:
            CloudSyncSettingsDetailView()
        }
    }
}

// MARK: - General Settings Detail View

struct GeneralSettingsDetailView: View {
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("useLocalLLM") private var useLocalLLM: Bool = true
    @AppStorage("localModelId") private var localModelId: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    @AppStorage("hfToken") private var hfToken: String = ""
    
    @EnvironmentObject var modelDownloadService: ModelDownloadService
    
    // Curated model options
    enum ModelOption: String, CaseIterable, Identifiable {
        case llama3B = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        case custom = "custom"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .llama3B: return "Llama 3.2 3B"
            case .custom: return "Custom Model"
            }
        }
        
        var description: String {
            switch self {
            case .llama3B: return "Balanced • ~2GB • High quality"
            case .custom: return "Enter custom model ID"
            }
        }
    }
    
    @State private var selectedModel: ModelOption = .llama3B
    @State private var customModelId: String = ""
    @State private var showCustomField: Bool = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Use Local LLM", isOn: $useLocalLLM)
                    .toggleStyle(.switch)
            } header: {
                Text("Artificial Intelligence")
            } footer: {
                if useLocalLLM {
                    Label("Processing happens entirely on your device using MLX. No data leaves your Mac.", systemImage: "lock.shield.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("Uses Gemini API for cloud-based processing.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            
            if useLocalLLM {
                // Hugging Face Token Section
                Section {
                    LabeledContent {
                        HStack(spacing: 8) {
                            SecureField("Enter your token", text: $hfToken)
                                .textFieldStyle(.roundedBorder)
                                .privacySensitive()
                                .onChange(of: hfToken) { _, newValue in
                                    if !newValue.isEmpty {
                                        setenv("HF_TOKEN", newValue, 1)
                                    }
                                }
                            
                            if !hfToken.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .imageScale(.medium)
                            }
                        }
                    } label: {
                        Text("Hugging Face Token")
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if hfToken.isEmpty {
                            Label("Required for model downloads", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        } else {
                            Label("Token configured successfully", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                        
                        Link("Get a free token from Hugging Face", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                            .font(.caption)
                    }
                }
                
                // Model Selection Section
                Section {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(ModelOption.allCases) { option in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.displayName)
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: selectedModel) { _, newValue in
                        showCustomField = (newValue == .custom)
                        if newValue != .custom {
                            localModelId = newValue.rawValue
                            Task {
                                if !modelDownloadService.isModelDownloaded(modelId: localModelId) && !hfToken.isEmpty {
                                    modelDownloadService.downloadModel(modelId: localModelId)
                                }
                            }
                        }
                    }
                    
                    if showCustomField {
                        LabeledContent("Custom Model ID") {
                            HStack(spacing: 8) {
                                TextField("e.g., mlx-community/Llama-3.2-1B-Instruct-4bit", text: $customModelId)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Use") {
                                    if !customModelId.isEmpty {
                                        localModelId = customModelId
                                        Task {
                                            if !modelDownloadService.isModelDownloaded(modelId: localModelId) && !hfToken.isEmpty {
                                                modelDownloadService.downloadModel(modelId: localModelId)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(customModelId.isEmpty)
                            }
                        }
                    }
                    
                    // Download Status
                    if case .downloading(let progress) = modelDownloadService.state {
                        LabeledContent("Download Progress") {
                            HStack(spacing: 8) {
                                ProgressView(value: progress)
                                    .frame(maxWidth: 200)
                                Text("\(Int(progress * 100))%")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                    } else if modelDownloadService.isModelDownloaded(modelId: localModelId) {
                        LabeledContent("Status") {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else if hfToken.isEmpty {
                        LabeledContent("Status") {
                            Label("Add token above to download", systemImage: "key.fill")
                                .foregroundStyle(.orange)
                        }
                    } else {
                        LabeledContent("Status") {
                            Label("Not downloaded", systemImage: "arrow.down.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Model Selection")
                } footer: {
                    Text("Select a pre-configured model or enter a custom Hugging Face model ID.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
            } else {
                // Gemini API Section
                Section {
                    LabeledContent("API Key") {
                        SecureField("Enter your Gemini API key", text: $geminiApiKey)
                            .textFieldStyle(.roundedBorder)
                            .privacySensitive()
                            .frame(maxWidth: 300)
                    }
                } header: {
                    Text("Gemini API")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Required for cloud-based data extraction.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        Link("Get an API key from Google AI Studio", destination: URL(string: "https://aistudio.google.com/")!)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let match = ModelOption.allCases.first(where: { $0.rawValue == localModelId }) {
                selectedModel = match
            } else {
                selectedModel = .custom
                customModelId = localModelId
                showCustomField = true
            }
        }
    }
}

// MARK: - Export Settings Detail View

struct ExportSettingsDetailView: View {
    @AppStorage("excelFilePath") private var excelFilePath: String = ""
    @State private var showFilePicker = false
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Excel File") {
                    HStack(spacing: 8) {
                        Text(excelFilePath.isEmpty ? "No file selected" : excelFilePath)
                            .foregroundStyle(excelFilePath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Choose...") {
                            showFilePicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                if !excelFilePath.isEmpty {
                    LabeledContent("Status") {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("Excel Export")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if excelFilePath.isEmpty {
                        Label("Choose an Excel file to get started", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                    
                    Text("Select an existing Excel file to update, or a new location to create one.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Duplicate Detection", systemImage: "doc.on.doc.fill")
                        .font(.subheadline)
                    
                    Text("Receipts with the same date, vendor, and amount will not be added twice.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Column Structure", systemImage: "tablecells.fill")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The Excel file will contain the following columns:")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        Text("Date • Vendor • Description • Category • Amount • Currency • Notes")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .monospaced()
                    }
                }
            } header: {
                Text("Information")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Export")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.init(filenameExtension: "xlsx")!, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    excelFilePath = url.path
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }
}

// MARK: - Organization Settings Detail View

struct OrganizationSettingsDetailView: View {
    @AppStorage("organizationBasePath") private var organizationBasePath: String = ""
    @AppStorage("autoOrganize") private var autoOrganize: Bool = true
    @State private var showFolderPicker = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-organize after export", isOn: $autoOrganize)
                    .toggleStyle(.switch)
            } header: {
                Text("File Organization")
            } footer: {
                Text("When enabled, receipts are automatically moved into a folder structure based on their date after export.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            
            Section {
                LabeledContent("Base Folder") {
                    HStack(spacing: 8) {
                        Text(organizationBasePath.isEmpty ? "No folder selected" : organizationBasePath)
                            .foregroundStyle(organizationBasePath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Choose...") {
                            showFolderPicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                if !organizationBasePath.isEmpty {
                    LabeledContent("Status") {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("Storage Location")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if organizationBasePath.isEmpty {
                        Label("Choose a base folder to get started", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                    
                    Text("Select the base folder where organized receipts will be stored.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Year/Month Organization", systemImage: "folder.fill")
                        .font(.subheadline)
                    
                    Text("Receipts are organized into: **BaseFolder/YYYY/mm - MMM yyyy/**")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BaseFolder/2025/06 - June 2025/receipt.pdf")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.blue)
                        
                        Text("BaseFolder/2025/12 - December 2025/invoice.pdf")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Example paths")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Missing Dates", systemImage: "calendar.badge.exclamationmark")
                        .font(.subheadline)
                    
                    Text("If a receipt's date cannot be extracted, it will not be moved. You'll be notified so you can organize it manually.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("Folder Structure")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Organization")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    organizationBasePath = url.path
                }
            case .failure(let error):
                print("Folder picker error: \(error)")
            }
        }
    }
}

// MARK: - Cloud Sync Settings Detail View

struct CloudSyncSettingsDetailView: View {
    @AppStorage("googleSheetId") private var googleSheetId: String = ""
    @AppStorage("googleClientID") private var clientID: String = ""
    @AppStorage("googleClientSecret") private var clientSecret: String = ""
    
    @State private var sheetInput: String = ""
    @State private var isFormatting = false
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Spreadsheet Link") {
                    TextField("Paste your Google Sheets URL", text: $sheetInput)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: sheetInput) { _, newValue in
                            extractSheetID(from: newValue)
                        }
                        .onAppear { sheetInput = googleSheetId }
                }
                
                if !googleSheetId.isEmpty && googleSheetId != sheetInput {
                    LabeledContent("Extracted ID") {
                        Text(googleSheetId)
                            .foregroundStyle(.green)
                            .font(.caption)
                            .monospaced()
                    }
                }
            } header: {
                Text("Google Sheets")
            } footer: {
                Text("Paste the full URL of your Google Sheet. The sheet ID will be extracted automatically.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            
            Section {
                LabeledContent("Client ID") {
                    TextField("Your OAuth 2.0 Client ID", text: $clientID)
                        .textFieldStyle(.roundedBorder)
                }
                
                LabeledContent("Client Secret") {
                    SecureField("Your OAuth 2.0 Client Secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)
                        .privacySensitive()
                }
            } header: {
                Text("OAuth Configuration")
            } footer: {
                Text("Required for Desktop App authentication with Google Cloud.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            
            if !googleSheetId.isEmpty {
                Section {
                    Button {
                        formatSheet()
                    } label: {
                        HStack {
                            if isFormatting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Label(isFormatting ? "Formatting..." : "Apply Professional Formatting",
                                  systemImage: "paintpalette.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFormatting)
                    .frame(maxWidth: .infinity, alignment: .center)
                } header: {
                    Text("Actions")
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "1.circle.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.large)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create Client ID")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Go to Google Cloud Console > APIs & Services > Credentials. Create an **OAuth 2.0 Client ID**.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "2.circle.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.large)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select 'Desktop App'")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Important: Select **Desktop App** as the Application Type (NOT iOS). This enables the required authentication flow.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "3.circle.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.large)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sign In")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Copy the Client ID & Secret above, then click 'Sign In' on the main screen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } header: {
                Text("Setup Guide")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Cloud Sync")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @MainActor
    private func formatSheet() {
        guard !googleSheetId.isEmpty else { return }
        isFormatting = true
        
        let core = ReceiptSorterCore(clientID: clientID, sheetID: googleSheetId)
        
        Task {
            do {
                if let auth = core.authService {
                    if !auth.isAuthorized {
                        if let window = NSApp.windows.first {
                            try await auth.signIn(presenting: window)
                        }
                    }
                }
                
                try await core.formatSheet()
                isFormatting = false
            } catch {
                print("Formatting failed: \(error)")
                isFormatting = false
            }
        }
    }
    
    private func extractSheetID(from input: String) {
        if input.contains("/d/") {
            let components = input.components(separatedBy: "/d/")
            if components.count > 1 {
                let idPart = components[1]
                if let idEndIndex = idPart.firstIndex(of: "/") {
                    self.googleSheetId = String(idPart[..<idEndIndex])
                } else {
                    self.googleSheetId = idPart
                }
                return
            }
        }
        
        if let queryIndex = input.firstIndex(of: "?") {
            self.googleSheetId = String(input[..<queryIndex])
        } else {
            self.googleSheetId = input
        }
    }
}
