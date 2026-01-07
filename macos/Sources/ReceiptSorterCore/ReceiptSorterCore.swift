import Foundation

@available(macOS 13.0, *)
public struct ReceiptSorterCore: Sendable {
    public private(set) var text = "Receipt Sorter Core"
    public let ocrService: OCRService


    public let geminiService: GeminiService?

    public let sheetService: SheetService?



    public init(apiKey: String? = nil, serviceAccountPath: String? = nil, sheetID: String? = nil) {

        self.ocrService = OCRService()

        

        if let apiKey = apiKey {

            self.geminiService = GeminiService(apiKey: apiKey)

        } else {

            self.geminiService = nil

        }

        

        if let serviceAccountPath = serviceAccountPath, let sheetID = sheetID {

            self.sheetService = SheetService(serviceAccountPath: serviceAccountPath, sheetID: sheetID)

        } else {

            self.sheetService = nil

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

    

    public func uploadToSheets(data: ReceiptData) async throws {

        guard let sheetService = sheetService else {

            throw SheetError.notConfigured

        }

        try await sheetService.appendReceipt(data)

    }

}



extension GeminiError {

    public static let notConfigured = NSError(domain: "GeminiError", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key not provided"])

}



extension SheetError {

    public static let notConfigured = NSError(domain: "SheetError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Google Sheets not configured"])

}
