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
            } else {
                Text("Select a settings category")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 550)
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
        ScrollView {
            VStack(spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Artificial Intelligence")
                            .font(.headline)
                        
                        Toggle("Use Local LLM (Privacy Focused)", isOn: $useLocalLLM)
                            .toggleStyle(.switch)
                        
                        if useLocalLLM {
                            Text("Processing happens entirely on your device using MLX. No data leaves your Mac.")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Divider()
                            
                            // HF Token Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Hugging Face Token")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if !hfToken.isEmpty {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                }
                                
                                SecureField("Enter your HF token", text: $hfToken)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: hfToken) { _, newValue in
                                        // Update environment variable immediately
                                        if !newValue.isEmpty {
                                            setenv("HF_TOKEN", newValue, 1)
                                        }
                                    }
                                
                                HStack(spacing: 4) {
                                    Text(hfToken.isEmpty ? "Required for model downloads." : "Token configured ✓")
                                        .font(.caption)
                                        .foregroundColor(hfToken.isEmpty ? .orange : .green)
                                    
                                    Spacer()
                                    
                                    Link("Get Free Token", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                                        .font(.caption)
                                }
                            }
                            
                            Divider()
                            
                            // Model Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Model Selection")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Model", selection: $selectedModel) {
                                    ForEach(ModelOption.allCases) { option in
                                        VStack(alignment: .leading) {
                                            Text(option.displayName)
                                                .font(.body)
                                            Text(option.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(option)
                                    }
                                }
                                .pickerStyle(.radioGroup)
                                .onChange(of: selectedModel) { _, newValue in
                                    showCustomField = (newValue == .custom)
                                    if newValue != .custom {
                                        localModelId = newValue.rawValue
                                        // Trigger download check
                                        Task {
                                            if !modelDownloadService.isModelDownloaded(modelId: localModelId) && !hfToken.isEmpty {
                                                modelDownloadService.downloadModel(modelId: localModelId)
                                            }
                                        }
                                    }
                                }
                                
                                if showCustomField {
                                    HStack {
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
                                        .disabled(customModelId.isEmpty)
                                    }
                                }
                                
                                // Download status
                                if case .downloading(let progress) = modelDownloadService.state {
                                    HStack {
                                        ProgressView(value: progress)
                                        Text("\(Int(progress * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                } else if modelDownloadService.isModelDownloaded(modelId: localModelId) {
                                    Label("Model Ready", systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else if hfToken.isEmpty {
                                    Label("Add HF token above to download", systemImage: "key")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Label("Model not downloaded", systemImage: "arrow.down.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                        } else {
                            SecureField("Gemini API Key", text: $geminiApiKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Required for data extraction.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Link("Get API Key", destination: URL(string: "https://aistudio.google.com/")!)
                                .font(.caption)
                        }
                    }
                    .padding()
                }
                .backgroundStyle(.background)
            }
            .padding(20)
        }
        .navigationTitle("General")
        .onAppear {
            // Set initial picker selection based on saved model ID
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
        ScrollView {
            VStack(spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Excel Export")
                            .font(.headline)
                        
                        HStack {
                            TextField("Excel File", text: $excelFilePath)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                            
                            Button("Choose...") {
                                showFilePicker = true
                            }
                        }
                        
                        if excelFilePath.isEmpty {
                            Label("No file selected", systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        } else {
                            Label("File configured", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        
                        Text("Select an existing Excel file to update, or a new location to create one.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .backgroundStyle(.background)
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Duplicate Detection", systemImage: "doc.on.doc")
                            Text("Receipts with the same date, vendor, and amount will not be added twice.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Label("Column Structure", systemImage: "tablecells")
                            Text("Date, Vendor, Description, Category (manual), Amount, Currency, Notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                .backgroundStyle(.background)
            }
            .padding(20)
        }
        .navigationTitle("Export")
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
        ScrollView {
            VStack(spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("File Organization")
                            .font(.headline)
                        
                        Toggle("Auto-organize after export", isOn: $autoOrganize)
                        
                        Text("When enabled, receipts are automatically moved into a folder structure based on their date after export.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 5)
                        
                        HStack {
                            TextField("Base Folder", text: $organizationBasePath)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                            
                            Button("Choose...") {
                                showFolderPicker = true
                            }
                        }
                        
                        if organizationBasePath.isEmpty {
                            Label("No folder selected", systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        } else {
                            Label("Folder configured", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        
                        Text("Select the base folder where organized receipts will be stored.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .backgroundStyle(.background)
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Folder Structure")
                            .font(.headline)
                        
                        HStack {
                            Label("Year/Month Organization", systemImage: "folder")
                            Text("Receipts are organized into: **BaseFolder/YYYY/mm - MMM yyyy/**")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Example:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("    BaseFolder/2025/06 - June 2025/receipt.pdf")
                                .font(.caption.monospaced())
                                .foregroundColor(.blue)
                                .fontDesign(.monospaced)
                        }
                        
                        Divider().padding(.vertical, 5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Missing Dates", systemImage: "calendar.badge.exclamationmark")
                            Text("If a receipt's date cannot be extracted, it will not be moved. You'll be notified so you can organize it manually.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                .backgroundStyle(.background)
            }
            .padding(20)
        }
        .navigationTitle("Organization")
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
        ScrollView {
            VStack(spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configuration")
                            .font(.headline)
                        
                        TextField("Spreadsheet Link", text: $sheetInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: sheetInput) { _, newValue in
                                extractSheetID(from: newValue)
                            }
                            .onAppear { sheetInput = googleSheetId }
                        
                        if !googleSheetId.isEmpty && googleSheetId != sheetInput {
                            Text("ID extracted: \(googleSheetId)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text("Paste the full URL of your Google Sheet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 5)
                        
                        TextField("OAuth Client ID", text: $clientID)
                            .textFieldStyle(.roundedBorder)
                        Text("Your Google Cloud OAuth 2.0 Client ID.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("OAuth Client Secret", text: $clientSecret)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Required for Desktop App authentication.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !googleSheetId.isEmpty {
                            Button(action: formatSheet) {
                                HStack {
                                    if isFormatting { ProgressView().controlSize(.small) }
                                    Text("🎨 Apply Professional Formatting")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isFormatting)
                            .padding(.top, 5)
                        }
                    }
                    .padding()
                }
                .backgroundStyle(.background)
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Setup Guide")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("1. Create Client ID", systemImage: "1.circle")
                            Text("Go to Google Cloud Console > APIs & Services > Credentials. Create an **OAuth 2.0 Client ID**.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Label("2. Select 'Desktop App'", systemImage: "2.circle")
                            Text("Important: Select **Desktop App** as the Application Type (NOT iOS). This enables the required authentication flow.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Label("3. Sign In", systemImage: "3.circle")
                            Text("Copy the Client ID & Secret above, then click 'Sign In' on the main screen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 5)
                    }
                    .padding()
                }
                .backgroundStyle(.background)
            }
            .padding(20)
        }
        .navigationTitle("Cloud Sync")
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
