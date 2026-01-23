@preconcurrency import SwiftUI
import ReceiptSorterCore
@preconcurrency import QuickLookUI
import UserNotifications
@preconcurrency import UniformTypeIdentifiers
import AppKit

// Wrapper to workaround NSItemProvider not being Sendable
struct UnsafeSendableWrapper<T>: @unchecked Sendable {
    let value: T
}

struct ProcessingItem: Identifiable, Equatable {
    let id = UUID()
    var url: URL  // Mutable to update after file organization
    var status: ItemStatus = .pending
    var data: ReceiptData?
    var error: String?
    var organized: Bool = false  // Track if file has been organized
    
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
    @AppStorage("useLocalLLM") private var useLocalLLM: Bool = true
    @AppStorage("localModelId") private var localModelId: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    @AppStorage("excelFilePath") private var excelFilePath: String = ""
    @AppStorage("googleSheetId") private var googleSheetId: String = ""
    @AppStorage("googleClientID") private var clientID: String = ""
    @AppStorage("googleClientSecret") private var clientSecret: String = ""
    @AppStorage("organizationBasePath") private var organizationBasePath: String = ""
    @AppStorage("autoOrganize") private var autoOrganize: Bool = true
    
    // State
    @State private var items: [ProcessingItem] = []
    @State private var selectedItemId: UUID?
    @State private var isBatchProcessing = false
    @State private var signInError: String?
    @State private var showSignInError = false
    
    // Core Logic State
    @State private var core: ReceiptSorterCore?
    @State private var isAuthorized = false
    
    // Duplicate Review State
    @State private var showDuplicateReview = false
    @State private var duplicateConflict: DuplicateConflict?
    @State private var existingMetadata: FileMetadata?
    @State private var newMetadata: FileMetadata?
    
    // Download Service
    @EnvironmentObject var modelDownloadService: ModelDownloadService
    
    var body: some View {
        VStack(spacing: 0) {
            // Model Download Banner
            if case .downloading = modelDownloadService.state {
                ModelDownloadBanner(downloadService: modelDownloadService)
            } else if case .failed = modelDownloadService.state {
                ModelDownloadBanner(downloadService: modelDownloadService)
            }
            
            NavigationSplitView {
                // SIDEBAR: File List
                VStack {
                if items.isEmpty {
                    WelcomeView(
                        apiKey: $apiKey,
                        useLocalLLM: $useLocalLLM,
                        excelFilePath: $excelFilePath,
                        organizationBasePath: $organizationBasePath,
                        isAuthorized: isAuthorized,
                        onSignIn: signIn
                    )
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
                        
                        if items.contains(where: { $0.status == .extracted }) {
                            // Primary: Export to Excel
                            Button(action: exportAllToExcel) {
                                HStack {
                                    Image(systemName: "doc.badge.arrow.up")
                                    Text("Export to Excel")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(excelFilePath.isEmpty)
                            .padding(.horizontal)
                            
                            // Secondary: Sync to Google Sheets
                            if isAuthorized {
                                Button(action: syncAll) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Sync to Google Sheets")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding([.horizontal, .bottom])
                            } else {
                                Spacer().frame(height: 8)
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
            .onAppear { initializeCore() }
            .onChange(of: apiKey) { _, _ in initializeCore() }
            .onChange(of: useLocalLLM) { _, _ in initializeCore() }
            .onChange(of: localModelId) { _, _ in initializeCore() }
            .onChange(of: excelFilePath) { _, _ in initializeCore() }
            .onChange(of: clientID) { _, _ in initializeCore() }
            .onChange(of: clientSecret) { _, _ in initializeCore() }
            .onChange(of: googleSheetId) { _, _ in initializeCore() }
            .onChange(of: organizationBasePath) { _, _ in initializeCore() }
            
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
                                Menu {
                                    Button("Export to Excel") { exportSingleToExcel(index) }
                                    if isAuthorized {
                                        Divider()
                                        Button("Sync to Google Sheets") { syncSingle(index) }
                                    }
                                } label: {
                                    Text("Export")
                                }
                                .menuStyle(.borderlessButton)
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
                                    DataCard(title: "Category", icon: "tag", value: data.category)
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
        .sheet(isPresented: $showDuplicateReview) {
            if let conflict = duplicateConflict {
                DuplicateReviewView(
                    conflict: conflict,
                    existingMetadata: existingMetadata,
                    newMetadata: newMetadata,
                    onResolution: { resolution in
                        handleDuplicateResolution(resolution, for: conflict)
                    }
                )
            }
        }
    }
    
    // MARK: - Logic
    
    @MainActor
    private func initializeCore() {
        let localService = useLocalLLM ? LocalLLMService(modelId: localModelId) : nil
        
        self.core = ReceiptSorterCore(
            apiKey: apiKey, 
            clientID: clientID, 
            clientSecret: clientSecret, 
            sheetID: googleSheetId, 
            excelFilePath: excelFilePath, 
            organizationBasePath: organizationBasePath,
            localLLMService: localService
        )
        
        Task {
            if let auth = core?.authService {
                self.isAuthorized = auth.isAuthorized
            }
        }
    }
    
    private func signIn() {
        guard let core = core, let auth = core.authService else { return }
        Task { @MainActor in
            do {
                if let window = NSApp.windows.first {
                    try await auth.signIn(presenting: window)
                    self.isAuthorized = true
                }
            } catch {
                print("Sign In Failed: \(error)")
            }
        }
    }
    
    @MainActor
    private func signOut() {
        guard let core = core, let auth = core.authService else { return }
        auth.signOut()
        self.isAuthorized = false
    }
    
    private func loadFiles(from providers: [NSItemProvider]) {
        // Workaround for NSItemProvider not being Sendable in strict concurrency checks
        // We wrap it to pass into the Task safely
        let safeProviders = UnsafeSendableWrapper(value: providers)
        
        Task { @MainActor in
            for provider in safeProviders.value {
                if let urlData = try? await provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    
                    let newItem = ProcessingItem(url: url)
                    items.append(newItem)
                    if items.count == 1 { selectedItemId = newItem.id }
                }
            }
            processBatch()
        }
    }
    
    @MainActor
    private func processBatch() {
        guard !isBatchProcessing else { return }
        isBatchProcessing = true
        Task {
            while let index = await MainActor.run(body: { items.firstIndex(where: { $0.status == .pending }) }) {
                await processItem(at: index)
            }
            await MainActor.run { 
                isBatchProcessing = false
                notify(title: "Batch Complete", body: "Finished processing receipts.") 
            }
        }
    }
    
    private func processItem(at index: Int) async {
        let item = await MainActor.run { items[index] }
        
        // Check configuration: Either API Key OR Local LLM must be enabled
        if !useLocalLLM && apiKey.isEmpty {
            await MainActor.run { items[index].error = "Missing API Key" }
            return
        }
        
        // Securely capture core on MainActor
        let core = await MainActor.run { self.core }
        guard let core = core else { return }
        
        await MainActor.run { items[index].status = .processing }
        
        do {
            let text = try await core.extractText(from: item.url)
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
            let indices = await MainActor.run { items.indices.filter { items[$0].status == .extracted } }
            for index in indices {
                await syncItem(at: index)
            }
        }
    }
    
    private func syncSingle(_ index: Int) {
        Task { await syncItem(at: index) }
    }
    
    private func syncItem(at index: Int) async {
        let item = await MainActor.run { items[index] }
        guard let data = item.data else { return }
        
        let core = await MainActor.run { self.core }
        guard let core = core else { return }
        
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
    
    // MARK: - Excel Export
    
    private func exportAllToExcel() {
        Task {
            let indices = await MainActor.run { items.indices.filter { items[$0].status == .extracted } }
            for index in indices {
                await exportItem(at: index)
            }
            await MainActor.run { notify(title: "Export Complete", body: "Receipts exported to Excel.") }
        }
    }
    
    private func exportSingleToExcel(_ index: Int) {
        Task { await exportItem(at: index) }
    }
    
    private func exportItem(at index: Int) async {
        let item = await MainActor.run { items[index] }
        guard let data = item.data else { return }
        
        let core = await MainActor.run { self.core }
        guard let core = core else { return }
        
        await MainActor.run { items[index].status = .syncing }
        do {
            try await core.exportToExcel(data: data)
            
            // Auto-organize file after successful export
            if await MainActor.run(body: { autoOrganize && !organizationBasePath.isEmpty }) {
                if let dateString = data.date, !dateString.isEmpty {
                    await organizeFileWithConflictDetection(at: index, date: dateString)
                }
            }
            
            await MainActor.run { items[index].status = .done }
        } catch {
            await MainActor.run {
                items[index].error = "Export Failed: \(error.localizedDescription)"
                items[index].status = .error
            }
        }
    }
    
    // MARK: - File Organization with Conflict Detection
    
    private func organizeFileWithConflictDetection(at index: Int, date: String) async {
        let core = await MainActor.run { self.core }
        guard let core = core,
              let service = core.fileOrganizationService else { return }
        
        let fileURL = await MainActor.run { items[index].url }
        
        do {
            let result = try await service.organizeReceiptWithConflictDetection(fileURL, date: date)
            
            switch result {
            case .success(let newURL):
                await MainActor.run {
                    items[index].url = newURL
                    items[index].organized = true
                }
                
            case .conflict(let existingURL, let proposedURL):
                // Get metadata for both files
                let existingMeta = await service.getFileMetadata(existingURL)
                let newMeta = await service.getFileMetadata(fileURL)
                
                // Show duplicate review dialog
                await MainActor.run {
                    self.duplicateConflict = DuplicateConflict(
                        existingURL: existingURL,
                        newFileURL: fileURL,
                        proposedURL: proposedURL,
                        itemIndex: index
                    )
                    self.existingMetadata = existingMeta
                    self.newMetadata = newMeta
                    self.showDuplicateReview = true
                }
                
            case .skipped(let reason):
                print("File organization skipped: \(reason)")
            }
        } catch {
            print("File organization failed: \(error.localizedDescription)")
        }
    }
    
    private func handleDuplicateResolution(_ resolution: ConflictResolution, for conflict: DuplicateConflict) {
        guard let core = self.core,
              let service = core.fileOrganizationService else { return }
        
        let index = conflict.itemIndex
        
        Task {
            do {
                let newURL = try await service.resolveConflict(
                    sourceURL: conflict.newFileURL,
                    existingURL: conflict.existingURL,
                    resolution: resolution
                )
                
                await MainActor.run {
                    if let newURL = newURL {
                        items[index].url = newURL
                        items[index].organized = true
                    }
                    // Clear conflict state
                    duplicateConflict = nil
                    existingMetadata = nil
                    newMetadata = nil
                }
            } catch {
                await MainActor.run {
                    items[index].error = "Resolution failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func icon(for item: ProcessingItem) -> String {
        if item.organized && item.status == .done {
            return "folder.circle.fill"  // Show folder icon for organized files
        }
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
        case .extracted: return "Ready to Export"
        case .syncing: return "Exporting..."
        case .done: return item.organized ? "Organized" : "Exported"
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

// MARK: - Welcome View

struct WelcomeView: View {
    @Binding var apiKey: String
    @Binding var useLocalLLM: Bool
    @Binding var excelFilePath: String
    @Binding var organizationBasePath: String
    let isAuthorized: Bool
    let onSignIn: () -> Void
    
    @State private var showApiKeySheet = false
    @State private var isHovering = false
    
    // Logic for panels
    private func openSpreadsheetPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an existing Excel spreadsheet"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                 // Access security scoped resource if needed (App Sandbox), 
                 // though NSOpenPanel usually handles this for the session.
                 // Ideally store bookmark data for persistence, but for now path is fine.
                 DispatchQueue.main.async {
                     self.excelFilePath = url.path
                 }
            }
        }
    }
    
    private func createNewSpreadsheet() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        panel.nameFieldStringValue = "Receipts.xlsx"
        panel.message = "Create a new spreadsheet"
        panel.prompt = "Create"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    // Use ExcelService to create a template
                    let service = ExcelService(fileURL: url)
                    do {
                        try await service.createNewSheet(with: [])
                        await MainActor.run {
                             self.excelFilePath = url.path
                        }
                    } catch {
                        print("Failed to create spreadsheet: \(error)")
                    }
                }
            }
        }
    }
    
    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folder]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select base folder for organization"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                 DispatchQueue.main.async {
                     self.organizationBasePath = url.path
                 }
            }
        }
    }
    
    private var isFullyConfigured: Bool {
        (!apiKey.isEmpty || useLocalLLM) && !excelFilePath.isEmpty && !organizationBasePath.isEmpty
    }
    
    private var configuredCount: Int {
        var count = 0
        if !apiKey.isEmpty || useLocalLLM { count += 1 }
        if !excelFilePath.isEmpty { count += 1 }
        if !organizationBasePath.isEmpty { count += 1 }
        return count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section with Gradient
            headerSection
                .padding(.top, 30)
                .padding(.bottom, 20)
            
            // Setup Status Section
            setupStatusSection
                .padding(.horizontal, 12)
            
            Spacer()
            
            // Drop Zone
            VStack(spacing: 12) {
                Divider().padding(.horizontal, 16)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                        .foregroundColor(isHovering ? .blue : Color.secondary.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 28))
                            .foregroundColor(isHovering ? .blue : .secondary)
                        
                        Text("Drop receipts here")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isHovering ? .blue : .secondary)
                        
                        if !isFullyConfigured {
                            Text("Complete setup above for best experience")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 16)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .onHover { hovering in
                    isHovering = hovering
                }
            }
            .padding(.bottom, 16)
            
            // Optional: Google Sign In for cloud sync
            if !isAuthorized {
                VStack(spacing: 8) {
                    Divider()
                    
                    Button(action: onSignIn) {
                        HStack {
                            Image(systemName: "cloud")
                            Text("Sign in for Cloud Sync")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showApiKeySheet) {
            apiKeySheetContent
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // App Icon with Glow Effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 15)
                
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("Welcome to Receipt Sorter")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Extract, organize, and export your receipts with AI")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var setupStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            setupHeader
            apiKeyCard
            excelCard
            organizationCard
        }
    }
    
    private var setupHeader: some View {
        HStack {
            Text("Setup")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(configuredCount)/3 configured")
                .font(.caption)
                .foregroundColor(isFullyConfigured ? .green : .orange)
        }
        .padding(.horizontal, 16)
    }
    
    private var apiKeyCard: some View {
        SetupCard(
            icon: useLocalLLM ? "cpu" : "key",
            title: useLocalLLM ? "Local AI (MLX)" : "Gemini API Key",
            subtitle: useLocalLLM ? "Running locally on device" : (apiKey.isEmpty ? "Required for extraction" : "Key configured"),
            isConfigured: useLocalLLM || !apiKey.isEmpty,
            actionLabel: useLocalLLM ? "Settings" : (apiKey.isEmpty ? "Set Key" : "Change"),
            action: { 
                if useLocalLLM {
                    showApiKeySheet = true 
                } else {
                    showApiKeySheet = true 
                }
            }
        )
    }
    
    private var excelCard: some View {
        let reveal: (() -> Void)? = excelFilePath.isEmpty ? nil : {
            NSWorkspace.shared.open(URL(fileURLWithPath: excelFilePath))
        }
        
        let createNew: (() -> Void)? = excelFilePath.isEmpty ? { self.createNewSpreadsheet() } : nil
        
        return SetupCard(
            icon: "doc.badge.arrow.up",
            title: "Spreadsheet",
            subtitle: excelFilePath.isEmpty ? "No file selected - Create or Choose one" : URL(fileURLWithPath: excelFilePath).lastPathComponent,
            isConfigured: !excelFilePath.isEmpty,
            actionLabel: excelFilePath.isEmpty ? "Choose File" : "Change",
            action: openSpreadsheetPicker,
            revealAction: reveal,
            secondaryActionLabel: excelFilePath.isEmpty ? "Create New" : nil,
            secondaryAction: createNew
        )
    }
    
    private var organizationCard: some View {
        SetupCard(
            icon: "folder.badge.gearshape",
            title: "Organization Folder",
            subtitle: organizationBasePath.isEmpty ? "No folder selected" : URL(fileURLWithPath: organizationBasePath).lastPathComponent,
            isConfigured: !organizationBasePath.isEmpty,
            actionLabel: organizationBasePath.isEmpty ? "Choose Folder" : "Change",
            action: openFolderPicker,
            revealAction: organizationBasePath.isEmpty ? nil : {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: organizationBasePath)
            }
        )
    }
    
    private var apiKeySheetContent: some View {
        VStack(spacing: 20) {
            Text("AI Configuration")
                .font(.headline)
            
            Toggle("Use Local LLM (Privacy Focused)", isOn: $useLocalLLM)
                .toggleStyle(.switch)
                .padding(.horizontal)
            
            if !useLocalLLM {
                Text("Gemini API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("Enter API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                Link("Get API Key", destination: URL(string: "https://aistudio.google.com/")!)
                    .font(.caption)
            } else {
                Text("Local LLM enabled. Models will be downloaded on first use.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 300)
            }
            
            HStack {
                Spacer()
                Button("Done") { showApiKeySheet = false }
                    .buttonStyle(.borderedProminent)
            }
            .frame(width: 300)
        }
        .padding(25)
    }
}

// MARK: - Setup Card Component

struct SetupCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isConfigured: Bool
    let actionLabel: String
    let action: () -> Void
    var revealAction: (() -> Void)? = nil
    var secondaryActionLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isConfigured ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isConfigured ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 18))
                    .foregroundColor(isConfigured ? .green : .orange)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let revealAction = revealAction {
                        Button(action: revealAction) {
                            Image(systemName: "magnifyingglass.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                if let secondaryLabel = secondaryActionLabel, let secondaryAction = secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button(action: action) {
                    Text(actionLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
    }
}