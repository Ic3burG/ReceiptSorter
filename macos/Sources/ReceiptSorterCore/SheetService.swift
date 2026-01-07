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
        // authService is @MainActor, so this await hops to the main thread automatically
        try await authService.performAction { accessToken in
            // This closure is executed back on the caller's context (or whatever performAction uses)
            // But performAction is @MainActor, so we should be careful.
            // Actually, we want to do the network request OFF the main thread.
            
            // So we capture the token and return, OR we do the work inside.
            // Since performAction takes an async closure, we can do work there.
            // BUT performAction is on MainActor. We don't want to block UI with URLSession.
            
            // Best approach: Get token, then do work.
            // But performAction is designed to wrap the action with a valid token.
            
            // Let's assume performAction executes the closure.
            
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
            
            // URLSession.shared.data is async and non-blocking, safe to call from MainActor
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

public enum SheetError: Error {
    case sheetsNotConfigured
    case apiError(String)
}