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
            }
            
            Section(header: Text("Setup Guide")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("1. Create Client ID", systemImage: "1.circle")
                    Text("Go to Google Cloud Console > APIs & Services > Credentials. Create an **OAuth 2.0 Client ID** for 'iOS' (works for macOS).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Label("2. Configure Redirect", systemImage: "2.circle")
                    Text("Use the Loopback IP: `http://127.0.0.1:0/callback` as the redirect URI if asked.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Label("3. Sign In", systemImage: "3.circle")
                    Text("Once configured, use the 'Sign In' button on the main screen to authorize access to your Sheets.")
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