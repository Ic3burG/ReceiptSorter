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
        try await authService.performAction { accessToken in
            let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(self.sheetID)/values/A1:append?valueInputOption=USER_ENTERED")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Construct row values as an array of JSON-compatible values
            // We use a custom Encodable wrapper to handle mixed types (String and Double)
            let rowValues: [SheetValue] = [
                .string(data.date ?? ""),
                .string(data.vendor ?? ""),
                .string(data.description ?? ""),
                .string(""), // Category
                .number(data.total_amount ?? 0),
                .string(data.currency ?? ""),
                .string("Uploaded via macOS (OAuth)")
            ]
            
            let body = SheetAppendRequest(values: [rowValues])
            
            request.httpBody = try JSONEncoder().encode(body)
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if let errorText = String(data: responseData, encoding: .utf8) {
                    throw SheetError.apiError(errorText)
                }
                throw SheetError.apiError("Unknown error")
            }
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
            let spreadsheet = try JSONDecoder().decode(Spreadsheet.self, from: metaData)
            
            guard let firstSheet = spreadsheet.sheets.first,
                  let sheetId = firstSheet.properties.sheetId else {
                throw SheetError.apiError("Could not find Sheet GID")
            }
            
            // 2. Prepare Formatting Requests
            let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(self.sheetID):batchUpdate")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let batchUpdate = BatchUpdateRequest(requests: [
                // Freeze Row 1
                Request(updateSheetProperties: UpdateSheetPropertiesRequest(
                    properties: SheetProperties(
                        sheetId: sheetId,
                        gridProperties: GridProperties(frozenRowCount: 1)
                    ),
                    fields: "gridProperties.frozenRowCount"
                )),
                // Format Header Row (Blue BG, White Bold Text)
                Request(repeatCell: RepeatCellRequest(
                    range: GridRange(sheetId: sheetId, startRowIndex: 0, endRowIndex: 1),
                    cell: CellData(userEnteredFormat: CellFormat(
                        backgroundColor: Color(red: 0.2, green: 0.4, blue: 0.8),
                        textFormat: TextFormat(foregroundColor: Color(red: 1, green: 1, blue: 1), bold: true, fontSize: 11),
                        horizontalAlignment: "CENTER"
                    )),
                    fields: "userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)"
                )),
                // Set Currency Format for Column E (Index 4)
                Request(repeatCell: RepeatCellRequest(
                    range: GridRange(sheetId: sheetId, startRowIndex: 1, startColumnIndex: 4, endColumnIndex: 5),
                    cell: CellData(userEnteredFormat: CellFormat(
                        numberFormat: NumberFormat(type: "CURRENCY", pattern: "$#,##0.00")
                    )),
                    fields: "userEnteredFormat.numberFormat"
                ))
            ])
            
            request.httpBody = try JSONEncoder().encode(batchUpdate)
            
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

// MARK: - Private Codable Structs for Sheets API

private struct SheetAppendRequest: Encodable {
    let values: [[SheetValue]]
}

private enum SheetValue: Encodable {
    case string(String)
    case number(Double)
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        }
    }
}

private struct Spreadsheet: Decodable {
    let sheets: [Sheet]
}

private struct Sheet: Decodable {
    let properties: SheetProperties
}

private struct SheetProperties: Codable {
    let sheetId: Int?
    let gridProperties: GridProperties?
    
    // For update requests where we only send part of the data
    init(sheetId: Int, gridProperties: GridProperties? = nil) {
        self.sheetId = sheetId
        self.gridProperties = gridProperties
    }
    
    // For decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sheetId = try container.decodeIfPresent(Int.self, forKey: .sheetId)
        gridProperties = try container.decodeIfPresent(GridProperties.self, forKey: .gridProperties)
    }
}

private struct GridProperties: Codable {
    let frozenRowCount: Int?
}

private struct BatchUpdateRequest: Encodable {
    let requests: [Request]
}

private struct Request: Encodable {
    let updateSheetProperties: UpdateSheetPropertiesRequest?
    let repeatCell: RepeatCellRequest?
    
    init(updateSheetProperties: UpdateSheetPropertiesRequest? = nil, repeatCell: RepeatCellRequest? = nil) {
        self.updateSheetProperties = updateSheetProperties
        self.repeatCell = repeatCell
    }
}

private struct UpdateSheetPropertiesRequest: Encodable {
    let properties: SheetProperties
    let fields: String
}

private struct RepeatCellRequest: Encodable {
    let range: GridRange
    let cell: CellData
    let fields: String
}

private struct GridRange: Encodable {
    let sheetId: Int
    let startRowIndex: Int?
    let endRowIndex: Int?
    let startColumnIndex: Int?
    let endColumnIndex: Int?
    
    init(sheetId: Int, startRowIndex: Int? = nil, endRowIndex: Int? = nil, startColumnIndex: Int? = nil, endColumnIndex: Int? = nil) {
        self.sheetId = sheetId
        self.startRowIndex = startRowIndex
        self.endRowIndex = endRowIndex
        self.startColumnIndex = startColumnIndex
        self.endColumnIndex = endColumnIndex
    }
}

private struct CellData: Encodable {
    let userEnteredFormat: CellFormat
}

private struct CellFormat: Encodable {
    let backgroundColor: Color?
    let textFormat: TextFormat?
    let horizontalAlignment: String?
    let numberFormat: NumberFormat?
    
    init(backgroundColor: Color? = nil, textFormat: TextFormat? = nil, horizontalAlignment: String? = nil, numberFormat: NumberFormat? = nil) {
        self.backgroundColor = backgroundColor
        self.textFormat = textFormat
        self.horizontalAlignment = horizontalAlignment
        self.numberFormat = numberFormat
    }
}

private struct Color: Encodable {
    let red: Double
    let green: Double
    let blue: Double
}

private struct TextFormat: Encodable {
    let foregroundColor: Color
    let bold: Bool
    let fontSize: Int
}

private struct NumberFormat: Encodable {
    let type: String
    let pattern: String
}
