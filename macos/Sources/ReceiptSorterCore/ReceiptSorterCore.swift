import Foundation

@available(macOS 10.15, *)
public struct ReceiptSorterCore {
    public private(set) var text = "Receipt Sorter Core"
    public let ocrService: OCRService

    public init() {
        self.ocrService = OCRService()
    }
    
    public func extractText(from fileURL: URL) async throws -> String {
        return try await ocrService.extractText(from: fileURL)
    }
}