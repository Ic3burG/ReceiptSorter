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
            
            SyncSettingsView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(Tabs.sync)
        }
        .padding(20)
        .frame(width: 450, height: 250)
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
    @AppStorage("serviceAccountPath") private var serviceAccountPath: String = "service_account.json"
    
    var body: some View {
        Form {
            Section(header: Text("Google Sheets")) {
                TextField("Spreadsheet ID", text: $googleSheetId)
                    .textFieldStyle(.roundedBorder)
                Text("The ID string from your Google Sheet URL.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Service Account Path", text: $serviceAccountPath)
                    .textFieldStyle(.roundedBorder)
                Text("Path to your service_account.json file.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
