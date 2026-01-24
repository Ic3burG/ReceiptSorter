import Foundation

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ReceiptSorterCore: Sendable {
    public let ocrService: OCRService
    public let dataExtractor: ReceiptDataExtractor?
    public let sheetService: SheetService?
    nonisolated(unsafe) public let authService: AuthService?
    public let excelService: ExcelService?
    public let fileOrganizationService: FileOrganizationService?

    /// Convenience init that creates AuthService internally
    /// Must be called from MainActor context due to AuthService requirements
    @MainActor
    public init(apiKey: String? = nil, clientID: String? = nil, clientSecret: String? = nil, sheetID: String? = nil, excelFilePath: String? = nil, organizationBasePath: String? = nil, localLLMService: ReceiptDataExtractor? = nil) {
        self.ocrService = OCRService()
        
        // Prefer local LLM if provided, otherwise fallback to Gemini if API key exists
        if let localLLMService = localLLMService {
            self.dataExtractor = localLLMService
        } else if let apiKey = apiKey, !apiKey.isEmpty {
            self.dataExtractor = GeminiService(apiKey: apiKey)
        } else {
            self.dataExtractor = nil
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
        NSLog("ReceiptSorterCore: OCR starting for file")
        let result = try await ocrService.extractText(from: fileURL)
        NSLog("ReceiptSorterCore: OCR complete, got \(result.count) chars")
        return result
    }
    
    public func extractReceiptData(from text: String) async throws -> ReceiptData {
        NSLog("ReceiptSorterCore: extractReceiptData called")
        guard let dataExtractor = dataExtractor else {
            NSLog("ReceiptSorterCore: No data extractor configured!")
            throw GeminiError.notConfigured
        }
        NSLog("ReceiptSorterCore: About to call dataExtractor.extractData...")
        let result = try await dataExtractor.extractData(from: text)
        NSLog("ReceiptSorterCore: dataExtractor.extractData completed successfully")
        return result
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
    
    // MARK: - File Organization
    
    /// Organize a receipt file into year/month folder structure based on its date
    /// - Parameters:
    ///   - fileURL: The URL of the receipt file to organize
    ///   - date: The receipt date in YYYY-MM-DD format
    /// - Returns: The new file URL after moving
    public func organizeFile(_ fileURL: URL, date: String) async throws -> URL {
        guard let service = fileOrganizationService else {
            throw FileOrganizationError.notConfigured
        }
        return try await service.organizeReceipt(fileURL, date: date)
    }
}

extension GeminiError {
    public static let notConfigured = NSError(domain: "GeminiError", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key not provided"])
}

public enum AuthError: LocalizedError {
    case authFailed(String)
    case notAuthorized
    case tokenRefreshFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .notAuthorized:
            return "Not authorized. Please sign in first."
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        }
    }
}
