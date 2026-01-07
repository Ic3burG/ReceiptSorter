import SwiftUI
import ReceiptSorterCore

struct ContentView: View {
    @State private var extractedText: String = "Drag a receipt here..."
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    // Initialize Core Logic
    let core = ReceiptSorterCore()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.text.viewfinder")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                Text("Receipt Sorter")
                    .font(.title)
                    .fontWeight(.bold)
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
                        ProgressView("Processing with Vision Framework...")
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
            .frame(height: 200)
            .padding()
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                processDroppedFiles(providers)
                return true
            }
            
            // Results Area
            VStack(alignment: .leading) {
                Text("Extracted Text:")
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
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func processDroppedFiles(_ providers: [NSItemProvider]) {
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
            
            // Pass the URL to the processing method (which handles main actor updates internally)
            DispatchQueue.main.async {
                self.processFile(at: url)
            }
        }
    }
    
    private func processFile(at url: URL) {
        self.isProcessing = true
        self.errorMessage = nil
        self.extractedText = "Analyzing \(url.lastPathComponent)..."
        
        // Capture core explicitly to avoid actor isolation issues
        let coreService = self.core
        
        Task {
            do {
                let text = try await coreService.extractText(from: url)
                await MainActor.run {
                    self.extractedText = text
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "OCR Failed: \(error.localizedDescription)"
                    self.extractedText = "Error"
                    self.isProcessing = false
                }
            }
        }
    }
}
