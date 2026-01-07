import Foundation

@available(macOS 12.0, *)
public struct ReceiptSorterCore: Sendable {
    public private(set) var text = "Receipt Sorter Core"
    public let ocrService: OCRService
    public let geminiService: GeminiService?

    public init(apiKey: String? = nil) {
        self.ocrService = OCRService()
        if let apiKey = apiKey {
            self.geminiService = GeminiService(apiKey: apiKey)
        } else {
            self.geminiService = nil
        }
    }
    
    public func extractText(from fileURL: URL) async throws -> String {
        return try await ocrService.extractText(from: fileURL)
    }
    
    public func extractReceiptData(from text: String) async throws -> ReceiptData {
        guard let geminiService = geminiService else {
            throw GeminiError.notConfigured
        }
        return try await geminiService.extractData(from: text)
    }
}

extension GeminiError {
    public static let notConfigured = NSError(domain: "GeminiError", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key not provided"])
}