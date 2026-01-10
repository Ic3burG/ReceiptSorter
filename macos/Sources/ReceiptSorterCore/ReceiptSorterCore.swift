import Foundation

@available(macOS 13.0, *)
public struct ReceiptSorterCore: Sendable {
    public let ocrService: OCRService
    public let geminiService: GeminiService?
    public let sheetService: SheetService?
    public let authService: AuthService?
    public let excelService: ExcelService?
    public let fileOrganizationService: FileOrganizationService?

    public init(apiKey: String? = nil, clientID: String? = nil, clientSecret: String? = nil, sheetID: String? = nil, excelFilePath: String? = nil, organizationBasePath: String? = nil) {
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
        
        if let excelFilePath = excelFilePath, !excelFilePath.isEmpty {
            self.excelService = ExcelService(fileURL: URL(fileURLWithPath: excelFilePath))
        } else {
            self.excelService = nil
        }
        
        if let organizationBasePath = organizationBasePath, !organizationBasePath.isEmpty {
            self.fileOrganizationService = FileOrganizationService(baseDirectory: URL(fileURLWithPath: organizationBasePath))
        } else {
            self.fileOrganizationService = nil
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
    
    // MARK: - Export Methods
    
    /// Export receipt data to local Excel file (primary export)
    public func exportToExcel(data: ReceiptData) async throws {
        guard let excelService = excelService else {
            throw ExcelError.fileNotConfigured
        }
        try await excelService.exportReceipt(data)
    }
    
    /// Upload receipt data to Google Sheets (secondary/cloud export)
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
