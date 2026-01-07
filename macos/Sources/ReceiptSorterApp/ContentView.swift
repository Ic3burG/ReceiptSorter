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
    @AppStorage("serviceAccountPath") private var serviceAccountPath: String = "service_account.json"
    
    // State
    @State private var items: [ProcessingItem] = []
    @State private var selectedItemId: UUID?
    @State private var isBatchProcessing = false
    
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
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                        loadFiles(from: providers)
                        return true
                    }
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
            
        } detail: {
            // DETAIL: Preview & Data
            if let selectedId = selectedItemId,
               let index = items.firstIndex(where: { $0.id == selectedId }) {
                let item = items[index]
                
                HSplitView {
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
                            if item.status == .extracted {
                                Button("Sync This") {
                                    syncSingle(index)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                if let data = item.data {
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
                                } else if let error = item.error {
                                    VStack(alignment: .leading) {
                                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                            .font(.headline)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                } else {
                                    VStack(spacing: 10) {
                                        if item.status == .processing {
                                            ProgressView()
                                            Text("Analyzing...")
                                        } else {
                                            Text("Waiting...")
                                        }
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
    }
    
    // MARK: - Logic
    
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
            // Trigger batch processing
            processBatch()
        }
    }
    
    private func processBatch() {
        guard !isBatchProcessing else { return }
        isBatchProcessing = true
        
        Task {
            for index in items.indices {
                if items[index].status == .pending {
                    await processItem(at: index)
                }
            }
            isBatchProcessing = false
            await MainActor.run {
                notify(title: "Batch Complete", body: "Finished processing receipts.")
            }
        }
    }
    
    private func processItem(at index: Int) async {
        guard !apiKey.isEmpty else {
            await MainActor.run { items[index].error = "Missing API Key" }
            return
        }
        
        await MainActor.run { items[index].status = .processing }
        
        let url = items[index].url
        let core = ReceiptSorterCore(apiKey: apiKey)
        
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
        guard !googleSheetId.isEmpty else { return }
        
        await MainActor.run { items[index].status = .syncing }
        
        // Ensure path resolves properly
        let path = serviceAccountPath
        let sheetID = googleSheetId
        
        do {
            // Run service on a background actor, but we can await it here
            let service = SheetService(serviceAccountPath: path, sheetID: sheetID)
            try await service.appendReceipt(data)
            
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
