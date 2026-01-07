import SwiftUI
import ReceiptSorterCore
import QuickLookUI
import UserNotifications

struct ProcessingItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var status: ItemStatus = .pending
    var data: ReceiptData?
    var error: String?
    
    enum ItemStatus: Equatable {
        case pending
        case processing
        case extracted
        case syncing
        case done
        case error
    }
}

struct ContentView: View {
    // Persistent Settings
    @AppStorage("geminiApiKey") private var apiKey: String = ""
    @AppStorage("googleSheetId") private var googleSheetId: String = ""
    @AppStorage("googleClientID") private var clientID: String = ""
    
    // State
    @State private var items: [ProcessingItem] = []
    @State private var selectedItemId: UUID?
    @State private var isBatchProcessing = false
    
    // Core (re-initialized when settings change)
    @State private var core: ReceiptSorterCore?
    @State private var isAuthorized = false
    
    var body: some View {
        NavigationSplitView {
            // ... (Sidebar code unchanged) ...
            VStack {
                if items.isEmpty {
                    // ...
                } else {
                    // ... (List code unchanged) ...
                    
                    // Batch Actions
                    VStack {
                        Divider()
                        HStack {
                            Text("\(items.count) files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Clear All") {
                                items.removeAll()
                                selectedItemId = nil
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                        .padding()
                        
                        if items.contains(where: { $0.status == .extracted }) {
                            if isAuthorized {
                                Button(action: syncAll) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Sync All Completed")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding([.horizontal, .bottom])
                            } else {
                                Button("Sign In to Sync") {
                                    signIn()
                                }
                                .frame(maxWidth: .infinity)
                                .padding([.horizontal, .bottom])
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            .background(Color(NSColor.controlBackgroundColor))
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                loadFiles(from: providers)
                return true
            }
            .onAppear {
                initializeCore()
            }
            .onChange(of: apiKey) { _ in initializeCore() }
            .onChange(of: clientID) { _ in initializeCore() }
            
        } detail: {
            // ... (Detail view code) ...
                            Spacer()
                            
                            if showSyncSuccess {
                                // ...
                            } else {
                                if isAuthorized {
                                    Button(action: { syncSingle(index) }) {
                                        HStack {
                                            if items[index].status == .syncing {
                                                ProgressView().controlSize(.small)
                                            } else {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                            }
                                            Text("Sync to Sheets")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(5)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .disabled(items[index].status == .syncing)
                                } else {
                                    Button("Sign In to Google") {
                                        signIn()
                                    }
                                    .controlSize(.large)
                                }
                            }
            // ...
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear { requestNotificationPermissions() }
    }
    
    // MARK: - Logic
    
    private func initializeCore() {
        self.core = ReceiptSorterCore(apiKey: apiKey, clientID: clientID, sheetID: googleSheetId)
        Task {
            if let auth = core?.authService {
                let authorized = await auth.isAuthorized
                await MainActor.run { self.isAuthorized = authorized }
            }
        }
    }
    
    private func signIn() {
        guard let core = core, let auth = core.authService else { return }
        
        Task {
            do {
                // Get the current window to present the auth session
                if let window = NSApp.windows.first {
                    try await auth.signIn(presenting: window)
                    await MainActor.run { self.isAuthorized = true }
                }
            } catch {
                print("Sign In Failed: \(error)")
            }
        }
    }
    
    private func loadFiles(from providers: [NSItemProvider]) {
        // ...
    }
    
    private func processBatch() {
        // ...
    }
    
    private func processItem(at index: Int) async {
        guard !apiKey.isEmpty else {
            await MainActor.run { items[index].error = "Missing API Key" }
            return
        }
        guard let core = self.core else { return } // Use initialized core
        
        await MainActor.run { items[index].status = .processing }
        
        let url = items[index].url
        
        do {
            let text = try await core.extractText(from: url)
            let data = try await core.extractReceiptData(from: text)
            
            await MainActor.run {
                items[index].data = data
                items[index].status = .extracted
            }
        } catch {
            await MainActor.run {
                items[index].error = error.localizedDescription
                items[index].status = .error
            }
        }
    }
    
    private func syncAll() {
        Task {
            for index in items.indices {
                if items[index].status == .extracted {
                    await syncItem(at: index)
                }
            }
        }
    }
    
    private func syncSingle(_ index: Int) {
        Task {
            await syncItem(at: index)
        }
    }
    
    private func syncItem(at index: Int) async {
        guard let data = items[index].data else { return }
        guard let core = self.core else { return }
        
        await MainActor.run { items[index].status = .syncing }
        
        do {
            try await core.uploadToSheets(data: data)
            
            await MainActor.run { items[index].status = .done }
        } catch {
            await MainActor.run {
                items[index].error = "Sync Failed: \(error.localizedDescription)"
                items[index].status = .error
            }
        }
    }
    
    // MARK: - Helpers
    
    private func icon(for item: ProcessingItem) -> String {
        switch item.status {
        case .pending: return "clock"
        case .processing: return "gear"
        case .extracted: return "checkmark.circle"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .done: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }
    
    private func color(for item: ProcessingItem) -> Color {
        switch item.status {
        case .done: return .green
        case .extracted: return .blue
        case .error: return .red
        default: return .secondary
        }
    }
    
    private func statusText(for item: ProcessingItem) -> String {
        switch item.status {
        case .pending: return "Queued"
        case .processing: return "Processing..."
        case .extracted: return "Ready to Sync"
        case .syncing: return "Syncing..."
        case .done: return "Synced"
        case .error: return "Failed"
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

struct DataCard: View {
    let title: String
    let icon: String
    let value: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value ?? "Unknown")
                .font(.body)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
