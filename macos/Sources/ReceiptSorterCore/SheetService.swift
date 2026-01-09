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
                    
                    public func formatHeader() async throws {
                        try await authService.performAction { accessToken in
                            // 1. Get Sheet Metadata to find the GID (Grid ID) of the first sheet
                            let metaUrl = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(self.sheetID)")!
                            var metaRequest = URLRequest(url: metaUrl)
                            metaRequest.httpMethod = "GET"
                            metaRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                            
                            let (metaData, _) = try await URLSession.shared.data(for: metaRequest)
                            // Parse Sheet ID 0 (usually the first tab)
                            // Simple parsing to avoid huge struct overhead for just one int
                            guard let json = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
                                  let sheets = json["sheets"] as? [[String: Any]],
                                  let firstSheet = sheets.first,
                                  let props = firstSheet["properties"] as? [String: Any],
                                  let sheetId = props["sheetId"] as? Int else {
                                throw SheetError.apiError("Could not find Sheet GID")
                            }
                            
                            // 2. Prepare Formatting Requests
                            let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(self.sheetID):batchUpdate")!
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            
                            let requests: [[String: Any]] = [
                                // Freeze Row 1
                                [
                                    "updateSheetProperties": [
                                        "properties": [
                                            "sheetId": sheetId,
                                            "gridProperties": ["frozenRowCount": 1]
                                        ],
                                        "fields": "gridProperties.frozenRowCount"
                                    ]
                                ],
                                // Format Header Row (Blue BG, White Bold Text)
                                [
                                    "repeatCell": [
                                        "range": [
                                            "sheetId": sheetId,
                                            "startRowIndex": 0,
                                            "endRowIndex": 1
                                        ],
                                        "cell": [
                                            "userEnteredFormat": [
                                                "backgroundColor": ["red": 0.2, "green": 0.4, "blue": 0.8],
                                                "textFormat": [
                                                    "foregroundColor": ["red": 1, "green": 1, "blue": 1],
                                                    "bold": true,
                                                    "fontSize": 11
                                                ],
                                                "horizontalAlignment": "CENTER"
                                            ]
                                        ],
                                        "fields": "userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)"
                                    ]
                                ],
                                // Set Currency Format for Column E (Index 4)
                                [
                                    "repeatCell": [
                                        "range": [
                                            "sheetId": sheetId,
                                            "startRowIndex": 1, // Skip header
                                            "startColumnIndex": 4,
                                            "endColumnIndex": 5
                                        ],
                                        "cell": [
                                            "userEnteredFormat": [
                                                "numberFormat": [
                                                    "type": "CURRENCY",
                                                    "pattern": "$#,##0.00"
                                                ]
                                            ]
                                        ],
                                        "fields": "userEnteredFormat.numberFormat"
                                    ]
                                ]
                            ]
                            
                            let body = ["requests": requests]
                            request.httpBody = try JSONSerialization.data(withJSONObject: body)
                            
                            let (data, response) = try await URLSession.shared.data(for: request)
                            
                            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                                if let errorText = String(data: data, encoding: .utf8) {
                                    throw SheetError.apiError(errorText)
                                }
                                throw SheetError.apiError("Formatting failed")
                            }
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
