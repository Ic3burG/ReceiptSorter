import SwiftUI
import ReceiptSorterCore

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, export, fileOrganization, cloudSync
    }
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            
            ScrollView {
                ExportSettingsView()
            }
            .tabItem {
                Label("Export", systemImage: "doc.badge.arrow.up")
            }
            .tag(Tabs.export)
            
            ScrollView {
                FileOrganizationSettingsView()
            }
            .tabItem {
                Label("Organization", systemImage: "folder.badge.gearshape")
            }
            .tag(Tabs.fileOrganization)
            
            ScrollView {
                SyncSettingsView()
            }
            .tabItem {
                Label("Cloud Sync", systemImage: "cloud")
            }
            .tag(Tabs.cloudSync)
        }
        .padding(20)
        .frame(width: 550, height: 500)
    }
}

struct ExportSettingsView: View {
    @AppStorage("excelFilePath") private var excelFilePath: String = ""
    @State private var showFilePicker = false
    
    var body: some View {
        Form {
            Section(header: Text("Excel Export")) {
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
            
            Section(header: Text("Tips")) {
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
        }
        .padding()
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

struct FileOrganizationSettingsView: View {
    @AppStorage("organizationBasePath") private var organizationBasePath: String = ""
    @AppStorage("autoOrganize") private var autoOrganize: Bool = true
    @State private var showFolderPicker = false
    
    var body: some View {
        Form {
            Section(header: Text("File Organization")) {
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
            
            Section(header: Text("Folder Structure")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Year/Month Organization", systemImage: "folder")
                    Text("Receipts are organized into: **BaseFolder/YYYY/MM/**")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Example: A receipt dated 2025-06-15 would be moved to:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("    BaseFolder/2025/06/receipt.pdf")
                        .font(.caption)
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
        }
        .padding()
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

struct GeneralSettingsView: View {
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Artificial Intelligence")) {
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
}

struct SyncSettingsView: View {

    @AppStorage("googleSheetId") private var googleSheetId: String = ""

    @AppStorage("googleClientID") private var clientID: String = ""

    @AppStorage("googleClientSecret") private var clientSecret: String = ""

    

    // Intermediate state for binding

        @State private var sheetInput: String = ""

        @State private var isFormatting = false

        

        var body: some View {

            Form {

                Section(header: Text("Configuration")) {

                    TextField("Spreadsheet Link", text: $sheetInput)

                        .textFieldStyle(.roundedBorder)

                        .onChange(of: sheetInput) { newValue in

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

    

    

                                Section(header: Text("Setup Guide")) {

    

    

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

            }

            .padding()

        }

        

        @MainActor
        private func formatSheet() {
            guard !googleSheetId.isEmpty else { return }
            isFormatting = true
            
            // Initialize core temporarily to use its services
            // ReceiptSorterCore init is @MainActor, so this is now safe
            let core = ReceiptSorterCore(clientID: clientID, sheetID: googleSheetId)
            
            Task {
                do {
                    // Ensure we are signed in first
                    // Access authService safely
                    if let auth = core.authService {
                        // isAuthorized is non-isolated property or actor-isolated? 
                        // AuthService is @MainActor class. So accessing .isAuthorized on MainActor is sync.
                        if !auth.isAuthorized {
                             if let window = NSApp.windows.first {
                                try await auth.signIn(presenting: window)
                             }
                        }
                    }
                    
                    try await core.formatSheet()
                    isFormatting = false
                } catch {
                    print("Formatting failed: \(error)") // Simple log for settings
                    isFormatting = false
                }
            }
        }

        

        private func extractSheetID(from input: String) {

    

            // Handle full URLs

    

            if input.contains("/d/") {

    

                let components = input.components(separatedBy: "/d/")

    

                if components.count > 1 {

    

                    let idPart = components[1]

    

                    // The ID ends at the next slash or end of string

    

                    if let idEndIndex = idPart.firstIndex(of: "/") {

    

                        self.googleSheetId = String(idPart[..<idEndIndex])

    

                    } else {

    

                        // ID might be the end of the string if no trailing slash

    

                        self.googleSheetId = idPart

    

                    }

    

                    return

    

                }

    

            }

    

            

    

            // If no /d/ found, assume the user pasted the ID directly

    

            // But clean up any potential query parameters just in case

    

            if let queryIndex = input.firstIndex(of: "?") {

    

                self.googleSheetId = String(input[..<queryIndex])

    

            } else {

    

                self.googleSheetId = input

    

            }

    

        }

    

    }

    

    
