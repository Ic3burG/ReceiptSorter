import Foundation

@available(macOS 13.0, *)
public actor SheetService {
    private let authService: AuthService
    private let sheetID: String
    
    public init(authService: AuthService, sheetID: String) {
        self.authService = authService
        self.sheetID = sheetID
    }
    
    public func appendReceipt(_ data: ReceiptData) async throws {
        // authService is a class, so we can call it directly. 
        // performAction is async.
        try await authService.performAction { accessToken in
            let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(self.sheetID)/values/A1:append?valueInputOption=USER_ENTERED")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let rowValues: [Any] = [
                data.date ?? "",
                data.vendor ?? "",
                data.description ?? "",
                "", // Category
                data.total_amount ?? 0,
                data.currency ?? "",
                "Uploaded via macOS (OAuth)"
            ]
            
            let body: [String: Any] = [
                "values": [rowValues]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if let errorText = String(data: responseData, encoding: .utf8) {
                    throw SheetError.apiError(errorText)
                }
                throw SheetError.apiError("Unknown error")
            }
        }
    }
}

public enum SheetError: LocalizedError {
    case sheetsNotConfigured
    case apiError(String)
    
    public var errorDescription: String? {
        switch self {
        case .sheetsNotConfigured:
            return "Google Sheets ID not configured in Settings."
        case .apiError(let message):
            return "Google Sheets API Error: \(message)"
        }
    }
}
