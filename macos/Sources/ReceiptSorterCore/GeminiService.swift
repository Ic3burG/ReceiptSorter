import Foundation
@preconcurrency import GoogleGenerativeAI

public struct ReceiptData: Codable, Sendable {
    public let total_amount: Double?
    public let currency: String?
    public let date: String?
    public let vendor: String?
    public let description: String?
}

@available(macOS 13.0, *)
public actor GeminiService {
    private let model: GenerativeModel
    
    public init(apiKey: String) {
        self.model = GenerativeModel(name: "gemini-1.5-flash", apiKey: apiKey)
    }
    
    public func extractData(from text: String) async throws -> ReceiptData {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.emptyInput
        }

        let prompt = """
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
        
        do {
    
                let response = try await model.generateContent(prompt)
    
                if let responseText = response.text {
    
                    return try parseResponse(responseText)
    
                } else {
    
                    // Analyze why text is missing
    
                    if let candidate = response.candidates.first {
    
                        let reason = candidate.finishReason
    
                        throw GeminiError.apiError("Blocked: \(reason)")
    
                    }
    
                    throw GeminiError.noResponse
    
                }
    
            } catch let error as GenerateContentError {
    
                // Unwrap specific Gemini errors
    
                switch error {
    
                case .internalError(let underlying):
    
                    throw GeminiError.apiError("Internal Error: \(underlying.localizedDescription)")
    
                case .promptBlocked(let response):
    
                    throw GeminiError.apiError("Prompt Blocked: \(response.text ?? "Unknown reason")")
    
                case .responseStoppedEarly(let reason, _):
    
                    throw GeminiError.apiError("Response Stopped: \(reason)")
    
                default:
    
                    throw GeminiError.apiError("Gemini Error: \(error.localizedDescription)")
    
                }
    
            } catch let error as GeminiError {
    
                throw error
    
            } catch {
    
                throw GeminiError.apiError(error.localizedDescription)
    
            }
    
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
    
                return "Gemini returned no text (content might be blocked)."
    
            case .invalidData:
    
                return "Could not parse JSON response from Gemini."
    
            case .emptyInput:
    
                return "OCR extracted no text. Cannot process empty receipt."
    
            case .apiError(let message):
    
                return "Gemini API Error: \(message)"
    
            }
    
        }
    
    }
    
    
