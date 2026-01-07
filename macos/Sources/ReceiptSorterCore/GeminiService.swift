import Foundation

public struct ReceiptData: Codable, Sendable {
    public let total_amount: Double?
    public let currency: String?
    public let date: String?
    public let vendor: String?
    public let description: String?
}

// Request/Response Structures for Gemini API
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let error: GeminiAPIError?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
}

struct GeminiAPIError: Codable {
    let code: Int
    let message: String
    let status: String
}

@available(macOS 13.0, *)
public actor GeminiService {
    private let apiKey: String
    private let modelName = "gemini-1.5-flash-latest"
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func extractData(from text: String) async throws -> ReceiptData {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.emptyInput
        }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.apiError("Invalid API URL")
        }
        
        let promptText = """
        Extract the following information from this receipt text and return it as a JSON object:
        
        Required fields:
        - total_amount: The total amount paid (numeric value only, no currency symbols)
        - currency: Currency code in ISO 4217 format (e.g., CAD, USD, EUR, GBP)
        - date: Transaction date in YYYY-MM-DD format
        - vendor: Name of the merchant/vendor
        - description: Brief description of items/services purchased (1-2 sentences max)
        
        Receipt text:
        \(text)
        
        Important instructions:
        1. For currency detection, look for currency symbols ($, €, £, ¥), currency codes, or infer from vendor location/language
        2. If the vendor appears to be Canadian or mentions CAD, use CAD as currency
        3. For the date, try multiple formats and convert to YYYY-MM-DD
        4. For total amount, use the final total after all taxes and fees
        5. If any field cannot be determined, use null.
        
        Return ONLY a valid JSON object. Do not include markdown formatting or explanations.
        """
        
        let requestBody = GeminiRequest(contents: [
            GeminiContent(parts: [GeminiPart(text: promptText)])
        ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug logging
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            // Try to parse error details
            if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let apiError = errorResponse.error {
                throw GeminiError.apiError("Google Error \(apiError.code): \(apiError.message)")
            }
            throw GeminiError.apiError("HTTP Error \(httpResponse.statusCode)")
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let candidate = geminiResponse.candidates?.first,
              let textPart = candidate.content.parts.first else {
            throw GeminiError.noResponse
        }
        
        return try parseResponse(textPart.text)
    }
    
    private func parseResponse(_ text: String) throws -> ReceiptData {
        // Clean markdown if present
        let cleanJSON = text.replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanJSON.data(using: .utf8) else {
            throw GeminiError.invalidData
        }
        
        return try JSONDecoder().decode(ReceiptData.self, from: data)
    }
}

public enum GeminiError: LocalizedError {
    case noResponse
    case invalidData
    case emptyInput
    case apiError(String)
    
    public var errorDescription: String? {
        switch self {
        case .noResponse:
            return "Gemini returned no text."
        case .invalidData:
            return "Could not parse JSON response from Gemini."
        case .emptyInput:
            return "OCR extracted no text."
        case .apiError(let message):
            return message
        }
    }
}