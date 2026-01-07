import SwiftUI
import ReceiptSorterCore
import QuickLookUI

struct ContentView: View {
    // Persistent Settings
    @AppStorage("geminiApiKey") private var apiKey: String = ""
    @AppStorage("googleSheetId") private var googleSheetId: String = ""
    @AppStorage("serviceAccountPath") private var serviceAccountPath: String = "service_account.json"
    
    // State
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var receiptData: ReceiptData?
    @State private var selectedFileURL: URL?
    @State private var showSyncSuccess = false
    
    var body: some View {
        HSplitView {
            // Left Pane: Document Preview
            ZStack {
                Color(NSColor.controlBackgroundColor)
                
                if let url = selectedFileURL {
                    if url.pathExtension.lowercased() == "pdf" {
                        PDFKitRepresentedView(url: url)
                    } else {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Drop Receipt Here")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Overlay loading state
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack {
                            ProgressView()
                                .controlSize(.large)
                            Text("Processing...")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.top, 5)
                        }
                        .padding()
                        .background(Material.thin)
                        .cornerRadius(12)
                    }
                }
            }
            .frame(minWidth: 300, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                processDroppedFiles(providers)
                return true
            }
            
            // Right Pane: Data & Actions
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Details")
                        .font(.headline)
                    Spacer()
                    if receiptData != nil {
                        Button("Clear") {
                            clearData()
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let data = receiptData {
                            DataCard(title: "Vendor", icon: "building.2", value: data.vendor)
                            DataCard(title: "Date", icon: "calendar", value: data.date)
                            DataCard(title: "Amount", icon: "dollarsign.circle", value: "\(String(format: "%.2f", data.total_amount ?? 0.0)) \(data.currency ?? "")")
                            DataCard(title: "Description", icon: "text.alignleft", value: data.description)
                            
                            Spacer()
                            
                            if showSyncSuccess {
                                Label("Synced Successfully!", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            } else {
                                Button(action: syncToSheets) {
                                    HStack {
                                        if isSyncing {
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
                                .disabled(isSyncing)
                            }
                            
                        } else if let error = errorMessage {
                            VStack(alignment: .leading) {
                                Label("Error", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.headline)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            Text("No data extracted.")
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
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func clearData() {
        self.selectedFileURL = nil
        self.receiptData = nil
        self.extractedText = ""
        self.errorMessage = nil
        self.showSyncSuccess = false
    }
    
    private func processDroppedFiles(_ providers: [NSItemProvider]) {
        guard !apiKey.isEmpty else {
            self.errorMessage = "Please set your Gemini API Key in Settings (Cmd+,)"
            return
        }
        
        guard let provider = providers.first else { return }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                return
            }
            
            guard let data = urlData as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async { self.errorMessage = "Could not load file." }
                return
            }
            
            DispatchQueue.main.async {
                self.selectedFileURL = url
                self.processFile(at: url)
            }
        }
    }
    
    private func processFile(at url: URL) {
        self.isProcessing = true
        self.errorMessage = nil
        self.receiptData = nil
        self.showSyncSuccess = false
        
        let core = ReceiptSorterCore(apiKey: apiKey)
        
        Task {
            do {
                let text = try await core.extractText(from: url)
                let data = try await core.extractReceiptData(from: text)
                
                await MainActor.run {
                    self.extractedText = text
                    self.receiptData = data
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func syncToSheets() {
        guard let data = receiptData else { return }
        
        guard !googleSheetId.isEmpty else {
            self.errorMessage = "Please configure Google Sheet ID in Settings (Cmd+,)"
            return
        }
        
        self.isSyncing = true
        self.errorMessage = nil
        
        // Ensure path resolves properly (if relative)
        let path = serviceAccountPath
        
        Task {
            do {
                let service = SheetService(serviceAccountPath: path, sheetID: googleSheetId)
                try await service.appendReceipt(data)
                
                await MainActor.run {
                    self.isSyncing = false
                    self.showSyncSuccess = true
                }
            } catch {
                await MainActor.run {
                    self.isSyncing = false
                    self.errorMessage = "Sync Failed: \(error.localizedDescription)"
                }
            }
        }
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