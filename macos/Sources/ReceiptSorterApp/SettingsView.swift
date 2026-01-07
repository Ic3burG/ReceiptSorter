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
    
    var body: some View {
        Form {
            Section(header: Text("Configuration")) {
                TextField("Spreadsheet ID", text: $googleSheetId)
                    .textFieldStyle(.roundedBorder)
                Text("Copy the ID from your browser URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("docs.google.com/spreadsheets/d/**1BxiMVs0XRA5nFMdKb...**/edit")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                
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
                    Text("Copy the Client ID above and click 'Sign In' on the main screen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
    }
}