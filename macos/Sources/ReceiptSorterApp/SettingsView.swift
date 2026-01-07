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
    @AppStorage("serviceAccountPath") private var serviceAccountPath: String = "service_account.json"
    
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
                
                TextField("Service Account Path", text: $serviceAccountPath)
                    .textFieldStyle(.roundedBorder)
                Text("Path to your credentials JSON file.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Setup Guide")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("1. Create Service Account", systemImage: "1.circle")
                    Text("Go to Google Cloud Console > IAM & Admin > Service Accounts. Create one and download the **JSON Key**.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Label("2. Save the File", systemImage: "2.circle")
                    Text("Move the downloaded JSON file into the 'receipt-sorter' folder and rename it to 'service_account.json' (or enter the full path above).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Label("3. Share the Sheet", systemImage: "3.circle")
                    Text("Open your Service Account JSON file, find the 'client_email', and **Share** your Google Sheet with that email address as an Editor.")
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
