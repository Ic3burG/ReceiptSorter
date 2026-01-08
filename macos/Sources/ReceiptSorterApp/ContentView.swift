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
    @AppStorage("googleClientSecret") private var clientSecret: String = ""
    
    // State
    @State private var items: [ProcessingItem] = []
    @State private var selectedItemId: UUID?
    @State private var isBatchProcessing = false
    @State private var signInError: String?
    @State private var showSignInError = false
    
    // Core Logic State
    @State private var core: ReceiptSorterCore?
    @State private var isAuthorized = false
    
    var body: some View {
        NavigationSplitView {
            // SIDEBAR: File List
            VStack {
                if items.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "square.stack.3d.down.right")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Drop Receipts Here")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if !isAuthorized {
                            Button("Sign In to Google") {
                                signIn()
                            }
                            .padding(.top, 10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedItemId) {
                        ForEach($items) { $item in
                            NavigationLink(value: item.id) {
                                HStack {
                                    Image(systemName: icon(for: item))
                                        .foregroundColor(color(for: item))
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.url.lastPathComponent)
                                            .font(.headline)
                                            .truncationMode(.middle)
                                        if let vendor = item.data?.vendor {
                                            Text(vendor).font(.caption).foregroundColor(.secondary)
                                        } else {
                                            Text(statusText(for: item)).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    
                    // Batch Actions
                    VStack(spacing: 12) {
                        Divider()
                        
                        // Authentication Status
                        HStack {
                            if isAuthorized {
                                Label("Signed In", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Spacer()
                                Button("Sign Out") {
                                    signOut()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                                .font(.caption)
                            } else {
                                Label("Not Signed In", systemImage: "circle")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Spacer()
                                Button("Sign In") {
                                    signIn()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                        
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
                        .padding([.top, .horizontal])
                        
                        if isAuthorized && items.contains(where: { $0.status == .extracted }) {
                            Button(action: syncAll) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Sync All Completed")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding([.horizontal, .bottom])
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
            .onAppear { initializeCore() }
            .onChange(of: apiKey) { _ in initializeCore() }
            .onChange(of: clientID) { _ in initializeCore() }
            .onChange(of: clientSecret) { _ in initializeCore() }
            .onChange(of: googleSheetId) { _ in initializeCore() }
            
        } detail: {
            // DETAIL: Preview & Data
            if let selectedId = selectedItemId,
               let index = items.firstIndex(where: { $0.id == selectedId }) {
                let item = items[index]
                
                HSplitView {
                    // ... (Preview Logic Unchanged) ...
                    // Preview (Left)
                    ZStack {
                        Color(NSColor.controlBackgroundColor)
                        if item.url.pathExtension.lowercased() == "pdf" {
                            PDFKitRepresentedView(url: item.url)
                        } else {
                            AsyncImage(url: item.url) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                            }
                        }
                    }
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Data (Right)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Details")
                                .font(.headline)
                            Spacer()
                            
                            // Action Buttons
                            if item.status == .extracted {
                                if isAuthorized {
                                    Button("Sync This") { syncSingle(index) }
                                }
                            } else if item.status == .error {
                                Button("Retry") {
                                    // Reset status and try processing again
                                    Task { await processItem(at: index) }
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                if let data = item.data {
                                    // ... (Data Cards Unchanged) ...
                                    DataCard(title: "Vendor", icon: "building.2", value: data.vendor)
                                    DataCard(title: "Date", icon: "calendar", value: data.date)
                                    DataCard(title: "Amount", icon: "dollarsign.circle", value: "\(String(format: "%.2f", data.total_amount ?? 0.0)) \(data.currency ?? "")")
                                    DataCard(title: "Description", icon: "text.alignleft", value: data.description)
                                    
                                    if item.status == .done {
                                        Label("Synced", systemImage: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                // Error State
                                if let error = item.error {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Processing Failed", systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                            .font(.headline)
                                        Text(error)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .background(Color.white)
                                            .cornerRadius(6)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                if item.status == .processing || item.status == .pending {
                                    VStack(spacing: 10) {
                                        ProgressView()
                                        Text(item.status == .processing ? "Analyzing..." : "Waiting...")
                                    }
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 50)
                                }
                            }
                            .padding()
                        }
                    }
                    .frame(minWidth: 250, maxWidth: 400, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            } else {
                Text("Select a receipt to view details")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear { requestNotificationPermissions() }
        .alert("Sign In Error", isPresented: $showSignInError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(signInError ?? "Unknown error")
        }
    }
    
    // MARK: - Logic
    
    private func initializeCore() {
        self.core = ReceiptSorterCore(apiKey: apiKey, clientID: clientID, clientSecret: clientSecret, sheetID: googleSheetId)
        Task { @MainActor in
            if let auth = core?.authService {
                self.isAuthorized = auth.isAuthorized
            }
        }
    }
    
    private func signIn() {
        guard let core = core, let auth = core.authService else { return }
        Task {
            do {
                if let window = NSApp.windows.first {
                    try await auth.signIn(presenting: window)
                    await MainActor.run { self.isAuthorized = true }
                }
            } catch {
                print("Sign In Failed: \(error)")
            }
        }
    }
    
    private func signOut() {
        guard let core = core, let auth = core.authService else { return }
        auth.signOut()
        self.isAuthorized = false
    }
    
    private func loadFiles(from providers: [NSItemProvider]) {
        Task {
            for provider in providers {
                if let urlData = try? await provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    
                    let newItem = ProcessingItem(url: url)
                    await MainActor.run {
                        items.append(newItem)
                        if items.count == 1 { selectedItemId = newItem.id }
                    }
                }
            }
            processBatch()
        }
    }
    
    private func processBatch() {
        guard !isBatchProcessing else { return }
        isBatchProcessing = true
        Task {
            while let index = items.firstIndex(where: { $0.status == .pending }) {
                await processItem(at: index)
            }
            isBatchProcessing = false
            await MainActor.run { notify(title: "Batch Complete", body: "Finished processing receipts.") }
        }
    }
    
    private func processItem(at index: Int) async {
        guard !apiKey.isEmpty else {
            await MainActor.run { items[index].error = "Missing API Key" }
            return
        }
        guard let core = self.core else { return }
        await MainActor.run { items[index].status = .processing }
        
        do {
            let text = try await core.extractText(from: items[index].url)
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
        Task { await syncItem(at: index) }
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
