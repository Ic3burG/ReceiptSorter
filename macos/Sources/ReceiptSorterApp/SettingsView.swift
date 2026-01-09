import SwiftUI

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, sync
    }
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            
            ScrollView {
                SyncSettingsView()
            }
            .tabItem {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            }
            .tag(Tabs.sync)
        }
        .padding(20)
        .frame(width: 500, height: 450)
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

        

        private func formatSheet() {

            guard !googleSheetId.isEmpty else { return }

            isFormatting = true

            

            // Initialize core temporarily to use its services

            let core = ReceiptSorterCore(clientID: clientID, sheetID: googleSheetId)

            

            Task {

                do {

                    // Ensure we are signed in first

                    if let auth = core.authService, await !auth.isAuthorized {

                        if let window = NSApp.windows.first {

                            try await auth.signIn(presenting: window)

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

    

    
