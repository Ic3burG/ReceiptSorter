import Foundation
import Vision
import CoreImage
import PDFKit

@available(macOS 10.15, *)
public final class OCRService: Sendable {
    
    public init() {}
    
    /// Extracts text from a file (Image or PDF) at the given URL
    public func extractText(from fileURL: URL) async throws -> String {
        let fileExtension = fileURL.pathExtension.lowercased()
        
        if fileExtension == "pdf" {
            return try await extractTextFromPDF(at: fileURL)
        } else {
            return try await extractTextFromImage(at: fileURL)
        }
    }
    
    private func extractTextFromImage(at fileURL: URL) async throws -> String {
        guard let ciImage = CIImage(contentsOf: fileURL) else {
            throw OCRError.invalidImage
        }
        return try await performRecognition(on: ciImage)
    }
    
    private func extractTextFromPDF(at fileURL: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            throw OCRError.invalidPDF
        }
        
        var fullText = ""
        let pageCount = pdfDocument.pageCount
        
        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            
            // Try native text extraction first (faster and more accurate for digital PDFs)
            if let pageText = page.string, pageText.count > 10 {
                fullText += pageText + "\n"
            } else {
                // Fallback to OCR: Render page to image
                
                // Get the page bounds
                let bounds = page.bounds(for: .mediaBox)
                
                // Create a representation (This is a simplified approach for macOS)
                // Reliable approach: Draw to NSImage/CGImage
                if let nsImage = page.thumbnail(of: bounds.size, for: .mediaBox).cgImage(forProposedRect: nil, context: nil, hints: nil) {
                     let ciImage = CIImage(cgImage: nsImage)
                     fullText += try await performRecognition(on: ciImage) + "\n"
                }
            }
        }
        
        return fullText
    }
    
    /// Performs the actual text recognition request
    private func performRecognition(on image: CIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    return observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

public enum OCRError: Error {
    case invalidImage
    case invalidPDF
    case recognitionFailed(String)
}
