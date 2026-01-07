import SwiftUI
import ReceiptSorterCore

struct ContentView: View {
    @State private var extractedText: String = "Drag a receipt here..."
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var apiKey: String = ""
    @State private var receiptData: ReceiptData?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.text.viewfinder")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Receipt Sorter")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    SecureField("Gemini API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
            .padding(.top)
            
            // Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(isProcessing ? .gray : .blue)
                    .background(Color(NSColor.controlBackgroundColor))
                
                VStack {
                    if isProcessing {
                        ProgressView("Analyzing with Vision & Gemini...")
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                            .padding()
                        Text("Drag & Drop Receipt PDF or Image")
                            .font(.headline)
                    }
                }
            }
            .frame(height: 150)
            .padding(.horizontal)
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                processDroppedFiles(providers)
                return true
            }
            
            // Results Area
            if let data = receiptData {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Extracted Data (Gemini)")
                        .font(.headline)
                    
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                        GridRow {
                            Text("Vendor:").bold()
                            Text(data.vendor ?? "Unknown")
                        }
                        GridRow {
                            Text("Date:").bold()
                            Text(data.date ?? "Unknown")
                        }
                        GridRow {
                            Text("Amount:").bold()
                            Text("\(String(format: "%.2f", data.total_amount ?? 0.0)) \(data.currency ?? "")")
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }

            VStack(alignment: .leading) {
                Text("Raw OCR Text:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(extractedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .padding([.horizontal, .bottom])
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom)
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }
    
    private func processDroppedFiles(_ providers: [NSItemProvider]) {
        guard !apiKey.isEmpty else {
            self.errorMessage = "Please enter your Gemini API Key first."
            return
        }
        
        guard let provider = providers.first else { return }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
            // Handle data extraction off the main actor
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let data = urlData as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not load file URL."
                }
                return
            }
            
            // Pass the URL to the processing method
            DispatchQueue.main.async {
                self.processFile(at: url)
            }
        }
    }
    
    private func processFile(at url: URL) {
        self.isProcessing = true
        self.errorMessage = nil
        self.receiptData = nil
        self.extractedText = "Extracting text from \(url.lastPathComponent)..."
        
        let core = ReceiptSorterCore(apiKey: apiKey)
        
        Task {
            do {
                // 1. OCR
                let text = try await core.extractText(from: url)
                await MainActor.run {
                    self.extractedText = text
                }
                
                // 2. Gemini
                let data = try await core.extractReceiptData(from: text)
                await MainActor.run {
                    self.receiptData = data
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Processing Failed: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}
