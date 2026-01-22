import Foundation
@preconcurrency import MLX
@preconcurrency import MLXLLM
@preconcurrency import MLXLMCommon

@available(macOS 14.0, *) 
public actor LocalLLMService: ReceiptDataExtractor {
    
    private let modelId: String
    private var modelContainer: ModelContainer?
    
    public init(modelId: String = "mlx-community/Llama-3.2-3B-Instruct-4bit") {
        self.modelId = modelId
    }
    
    private func ensureModelLoaded() async throws {
        if modelContainer != nil { return }
        
        let config = ModelConfiguration(id: modelId)
        self.modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)
    }
    
    public func extractData(from text: String) async throws -> ReceiptData {
        try await ensureModelLoaded()
        
        guard let modelContainer = modelContainer else {
            throw LocalLLMError.modelLoadFailed
        }
        
        let canadianCategories = TaxCategories.canadian.joined(separator: ", ")
        let usCategories = TaxCategories.us.joined(separator: ", ")
        
        let systemPrompt = """
        You are a receipt data extraction assistant. Extract the following information from the receipt text and return it as a VALID JSON object.
        
        Required fields:
        - total_amount: The total amount paid (numeric value only, no currency symbols)
        - currency: Currency code in ISO 4217 format (e.g., CAD, USD)
        - date: Transaction date in YYYY-MM-DD format
        - vendor: Name of the merchant/vendor
        - description: Brief description of items/services purchased
        - category: The best matching tax category from the provided lists
        
        Tax Categories:
        - Canadian Categories: \(canadianCategories)
        - US Categories: \(usCategories)
        
        Instructions:
        1. Look for currency symbols or location context. If uncertain, default to CAD.
        2. Convert date to YYYY-MM-DD.
        3. Use the final total amount.
        4. Return ONLY the JSON object. No markdown, no "Here is the JSON", just the raw JSON.
        """
        
        let userPrompt = "Receipt text:\n\(text)"
        
        // Use Chat struct from MLXLMCommon
        let chat: [Chat.Message] = [
            .system(systemPrompt),
            .user(userPrompt)
        ]
        
        let userInput = UserInput(chat: chat)
        
        // Prepare input using the container (handles tokenization and chat template)
        let input = try await modelContainer.prepare(input: userInput)
        
        // Generate parameters
        let parameters = GenerateParameters(maxTokens: 1024, temperature: 0.1)
        
        // Generate stream
        let stream = try await modelContainer.generate(input: input, parameters: parameters)
        
        var fullOutput = ""
        for await event in stream {
            switch event {
            case .chunk(let text):
                fullOutput += text
            default:
                break
            }
        }
        
        return try parseResponse(fullOutput)
    }
    
    private func parseResponse(_ text: String) throws -> ReceiptData {
        // Clean up common LLM artifacts
        let cleanJSON = text.replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanJSON.data(using: .utf8) else {
            throw LocalLLMError.invalidData
        }
        
        do {
            return try JSONDecoder().decode(ReceiptData.self, from: data)
        } catch {
            print("Failed to decode JSON: \(cleanJSON)")
            throw error
        }
    }
}

public enum LocalLLMError: LocalizedError {
    case modelLoadFailed
    case invalidData
    case generationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed: return "Failed to load local LLM model."
        case .invalidData: return "Could not parse JSON response from local model."
        case .generationFailed(let msg): return "Generation failed: \(msg)"
        }
    }
}