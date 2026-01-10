import Foundation

@available(macOS 13.0, *)
public struct ReceiptSorterCore: Sendable {
    public let ocrService: OCRService
    public let geminiService: GeminiService?
    public let sheetService: SheetService?
    public let authService: AuthService?

    public init(apiKey: String? = nil, clientID: String? = nil, clientSecret: String? = nil, sheetID: String? = nil) {
        self.ocrService = OCRService()
        
        if let apiKey = apiKey, !apiKey.isEmpty {
            self.geminiService = GeminiService(apiKey: apiKey)
        } else {
            self.geminiService = nil
        }
        
        if let clientID = clientID, !clientID.isEmpty {
            let auth = AuthService(clientID: clientID, clientSecret: clientSecret)
            self.authService = auth
            if let sheetID = sheetID, !sheetID.isEmpty {
                self.sheetService = SheetService(authService: auth, sheetID: sheetID)
            } else {
                self.sheetService = nil
            }
        } else {
            self.authService = nil
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
            throw SheetError.sheetsNotConfigured
        }
        try await sheetService.appendReceipt(data)
    }
    
    public func formatSheet() async throws {
        guard let sheetService = sheetService else {
            throw SheetError.sheetsNotConfigured
        }
        try await sheetService.formatHeader()
    }
}

extension GeminiError {
    public static let notConfigured = NSError(domain: "GeminiError", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key not provided"])
}