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
            .lgSidebarStyle() // Apply Glass Sidebar Style
        } detail: {
            // Detail view
            ZStack {
                // Background
                Color.clear
                    .glassSurface(intensity: .subtle)
                    .ignoresSafeArea()
                
                if let section = selectedSection {
                    settingsDetailView(for: section)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    Text("Select a settings category")
                        .font(LiquidGlassTypography.title) // Use new typography
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 800, height: 600) // Increased size for better layout
        .background(LiquidGlassColors.glassDark) // Overall window background
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
                LGGroupBox {
                    Text("Artificial Intelligence").font(LiquidGlassTypography.headline)
                } content: {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Use Local LLM (Privacy Focused)", isOn: $useLocalLLM)
                            .toggleStyle(.switch)
                            .font(LiquidGlassTypography.body)
                        
                        if useLocalLLM {
                            Text("Processing happens entirely on your device using MLX. No data leaves your Mac.")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.green)
                            
                            Divider()
                            
                            // HF Token Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Hugging Face Token")
                                        .font(LiquidGlassTypography.headline)
                                    
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
                                
                                LGTextField("Enter your HF token", text: $hfToken, isSecure: true)
                                    .onChange(of: hfToken) { _, newValue in
                                        // Update environment variable immediately
                                        if !newValue.isEmpty {
                                            setenv("HF_TOKEN", newValue, 1)
                                        }
                                    }
                                
                                HStack(spacing: 4) {
                                    Text(hfToken.isEmpty ? "Required for model downloads." : "Token configured ✓")
                                        .font(LiquidGlassTypography.caption)
                                        .foregroundColor(hfToken.isEmpty ? .orange : .green)
                                    
                                    Spacer()
                                    
                                    Link("Get Free Token", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                                        .font(LiquidGlassTypography.caption)
                                }
                            }
                            
                            Divider()
                            
                            // Model Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Model Selection")
                                    .font(LiquidGlassTypography.headline)
                                
                                Picker("Model", selection: $selectedModel) {
                                    ForEach(ModelOption.allCases) { option in
                                        VStack(alignment: .leading) {
                                            Text(option.displayName)
                                                .font(LiquidGlassTypography.body)
                                            Text(option.description)
                                                .font(LiquidGlassTypography.caption)
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
                                    HStack(spacing: 12) {
                                        LGTextField("e.g., mlx-community/Llama-3.2-1B-Instruct-4bit", text: $customModelId)
                                        
                                        LGButton("Use", style: .primary) {
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
                                            .font(LiquidGlassTypography.caption)
                                            .foregroundColor(.blue)
                                    }
                                } else if modelDownloadService.isModelDownloaded(modelId: localModelId) {
                                    Label("Model Ready", systemImage: "checkmark.circle")
                                        .font(LiquidGlassTypography.caption)
                                        .foregroundColor(.green)
                                } else if hfToken.isEmpty {
                                    Label("Add HF token above to download", systemImage: "key")
                                        .font(LiquidGlassTypography.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Label("Model not downloaded", systemImage: "arrow.down.circle")
                                        .font(LiquidGlassTypography.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                        } else {
                            LGTextField("Gemini API Key", text: $geminiApiKey, isSecure: true)
                            
                            Text("Required for data extraction.")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                            
                            Link("Get API Key", destination: URL(string: "https://aistudio.google.com/")!)
                                .font(LiquidGlassTypography.caption)
                        }
                    }
                }
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
                LGGroupBox {
                    Text("Excel Export").font(LiquidGlassTypography.headline)
                } content: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            LGTextField("Excel File", text: $excelFilePath)
                                .disabled(true)
                            
                            LGButton("Choose...") {
                                showFilePicker = true
                            }
                        }
                        
                        if excelFilePath.isEmpty {
                            Label("No file selected", systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(LiquidGlassTypography.caption)
                        } else {
                            Label("File configured", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(LiquidGlassTypography.caption)
                        }
                        
                        Text("Select an existing Excel file to update, or a new location to create one.")
                            .font(LiquidGlassTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                LGCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips")
                            .font(LiquidGlassTypography.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Duplicate Detection", systemImage: "doc.on.doc")
                                .font(LiquidGlassTypography.body)
                            Text("Receipts with the same date, vendor, and amount will not be added twice.")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                            
                            Label("Column Structure", systemImage: "tablecells")
                                .font(LiquidGlassTypography.body)
                            Text("Date, Vendor, Description, Category (manual), Amount, Currency, Notes")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
                LGGroupBox {
                    Text("File Organization").font(LiquidGlassTypography.headline)
                } content: {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Auto-organize after export", isOn: $autoOrganize)
                            .toggleStyle(.switch)
                            .font(LiquidGlassTypography.body)
                        
                        Text("When enabled, receipts are automatically moved into a folder structure based on their date after export.")
                            .font(LiquidGlassTypography.caption)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 5)
                        
                        HStack {
                            LGTextField("Base Folder", text: $organizationBasePath)
                                .disabled(true)
                            
                            LGButton("Choose...") {
                                showFolderPicker = true
                            }
                        }
                        
                        if organizationBasePath.isEmpty {
                            Label("No folder selected", systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(LiquidGlassTypography.caption)
                        } else {
                            Label("Folder configured", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(LiquidGlassTypography.caption)
                        }
                        
                        Text("Select the base folder where organized receipts will be stored.")
                            .font(LiquidGlassTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                LGCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Folder Structure")
                            .font(LiquidGlassTypography.headline)
                        
                        HStack {
                            Label("Year/Month Organization", systemImage: "folder")
                                .font(LiquidGlassTypography.body)
                            Text("Receipts are organized into: **BaseFolder/YYYY/mm - MMM yyyy/**")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Example:")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                            Text("    BaseFolder/2025/06 - June 2025/receipt.pdf")
                                .font(LiquidGlassTypography.code)
                                .foregroundColor(.blue)
                        }
                        
                        Divider().padding(.vertical, 5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Missing Dates", systemImage: "calendar.badge.exclamationmark")
                                .font(LiquidGlassTypography.body)
                            Text("If a receipt's date cannot be extracted, it will not be moved. You'll be notified so you can organize it manually.")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
                LGGroupBox {
                    Text("Configuration").font(LiquidGlassTypography.headline)
                } content: {
                    VStack(alignment: .leading, spacing: 12) {
                        LGTextField("Spreadsheet Link", text: $sheetInput)
                            .onChange(of: sheetInput) { _, newValue in
                                extractSheetID(from: newValue)
                            }
                            .onAppear { sheetInput = googleSheetId }
                        
                        if !googleSheetId.isEmpty && googleSheetId != sheetInput {
                            Text("ID extracted: \(googleSheetId)")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text("Paste the full URL of your Google Sheet.")
                            .font(LiquidGlassTypography.caption)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 5)
                        
                        LGTextField("OAuth Client ID", text: $clientID)
                        Text("Your Google Cloud OAuth 2.0 Client ID.")
                            .font(LiquidGlassTypography.caption)
                            .foregroundColor(.secondary)
                        
                        LGTextField("OAuth Client Secret", text: $clientSecret, isSecure: true)
                        
                        Text("Required for Desktop App authentication.")
                            .font(LiquidGlassTypography.caption)
                            .foregroundColor(.secondary)
                        
                        if !googleSheetId.isEmpty {
                            LGButton(isFormatting ? "Formatting..." : "Apply Professional Formatting", 
                                   icon: isFormatting ? nil : "paintpalette", 
                                   style: .primary) {
                                formatSheet()
                            }
                            .disabled(isFormatting)
                            .padding(.top, 5)
                        }
                    }
                }
                
                LGCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Setup Guide")
                            .font(LiquidGlassTypography.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("1. Create Client ID", systemImage: "1.circle")
                                .font(LiquidGlassTypography.body)
                            Text("Go to Google Cloud Console > APIs & Services > Credentials. Create an **OAuth 2.0 Client ID**.")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Label("2. Select 'Desktop App'", systemImage: "2.circle")
                                .font(LiquidGlassTypography.body)
                            Text("Important: Select **Desktop App** as the Application Type (NOT iOS). This enables the required authentication flow.")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Label("3. Sign In", systemImage: "3.circle")
                                .font(LiquidGlassTypography.body)
                            Text("Copy the Client ID & Secret above, then click 'Sign In' on the main screen.")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 5)
                    }
                }
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
