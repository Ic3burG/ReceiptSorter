/*
 * ReceiptSorter
 * Copyright (c) 2025 OJD Technical Solutions
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Commercial licensing is available for enterprises.
 * Please contact OJD Technical Solutions for details.
 */

import Foundation
import Hub
@preconcurrency import MLX
@preconcurrency import MLXLLM
@preconcurrency import MLXLMCommon
import Tokenizers

@available(macOS 14.0, *)
public actor LocalLLMService: ReceiptDataExtractor {

  private let modelId: String
  private var modelContainer: ModelContainer?
  // `let` + all accesses via MainActor.run — safe despite nonisolated(unsafe)
  nonisolated(unsafe) private let correctionStore: CorrectionStore

  public init(modelId: String = GemmaModel.modelId, correctionStore: CorrectionStore) {
    self.modelId = modelId
    self.correctionStore = correctionStore
    NSLog("ReceiptSorter: [LLM] LocalLLMService initialized with model: \(modelId)")
  }

  public func isModelReady() -> Bool {
    let repo = Hub.Repo(id: modelId)
    let modelURL = HubApi.shared.localRepoLocation(repo)

    let configURL = modelURL.appendingPathComponent("config.json")
    guard FileManager.default.fileExists(atPath: configURL.path) else { return false }

    let enumerator = FileManager.default.enumerator(
      at: modelURL, includingPropertiesForKeys: nil)
    while let url = enumerator?.nextObject() as? URL {
      if url.pathExtension == "safetensors" { return true }
    }
    return false
  }

  private func ensureModelLoaded() async throws {
    if modelContainer != nil { return }

    // Safety check
    guard isModelReady() else {
      throw LocalLLMError.modelNotDownloaded
    }

    // Load using explicit directory path to ensure consistency
    let repo = Hub.Repo(id: modelId)
    let modelURL = HubApi.shared.localRepoLocation(repo)

    NSLog("ReceiptSorter: Loading local model from: \(modelURL.path)")
    do {
      self.modelContainer = try await LLMModelFactory.shared.loadContainer(
        from: modelURL,
        using: HuggingFaceTokenizerLoader()
      )
      NSLog("ReceiptSorter: Model container loaded successfully.")
    } catch {
      NSLog(
        "ReceiptSorter: CRITICAL - Failed to load model container: \(error.localizedDescription)")
      throw error
    }
  }

  public func extractData(from text: String) async throws -> ReceiptData {
    // CRASH DEBUG: Log immediately at function entry
    NSLog("ReceiptSorter: [LLM] extractData ENTRY - function called")

    NSLog("ReceiptSorter: Starting data extraction via Local LLM...")
    do {
      NSLog("ReceiptSorter: [LLM] About to call ensureModelLoaded...")
      try await ensureModelLoaded()
      NSLog("ReceiptSorter: [LLM] ensureModelLoaded returned successfully")
    } catch {
      NSLog("ReceiptSorter: Failed to ensure model loaded: \(error.localizedDescription)")
      throw error
    }

    guard let modelContainer = modelContainer else {
      NSLog("ReceiptSorter: Model container is nil after load attempt")
      throw LocalLLMError.modelLoadFailed
    }

    // Fetch few-shot corrections from the store (MainActor call from actor context)
    let fewShotSnippet = await MainActor.run { correctionStore.buildFewShotSnippet() }

    let systemPromptBase = """
      You are a receipt scanner AI. Extract data from the receipt below into JSON.

      JSON Schema:
      {
        "vendor": "string",
        "date": "YYYY-MM-DD",
        "total_amount": number,
        "currency": "CAD",
        "category": "string",
        "description": "string"
      }

      Categories: Groceries, Dining, Gas, Transport, Shopping, Other

      Instructions:
      - Output ONLY valid JSON.
      - "category" must be one of the Categories list.
      - If currency is unknown, use "CAD".
      - Do not use markdown.
      """

    let systemPrompt = fewShotSnippet.map { $0 + "\n\n" + systemPromptBase } ?? systemPromptBase

    let userPrompt = "Receipt text:\n\(text)"

    // Use Chat struct from MLXLMCommon
    let chat: [Chat.Message] = [
      .system(systemPrompt),
      .user(userPrompt),
    ]

    let userInput = UserInput(chat: chat)

    do {
      NSLog("ReceiptSorter: Preparing model input...")
      let input = try await modelContainer.prepare(input: userInput)

      // Generate parameters - add repetitionPenalty to prevent loops
      let parameters = GenerateParameters(
        maxTokens: 1024,
        temperature: 0.1,
        repetitionPenalty: 1.1
      )

      NSLog("ReceiptSorter: Starting generation stream...")
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

      NSLog("ReceiptSorter: Generation complete. Parsing response...")
      let parsed = try parseResponse(fullOutput)
      let corrected = await MainActor.run { correctionStore.applyRules(to: parsed) }
      return corrected
    } catch {
      NSLog("ReceiptSorter: Generation or Parse failed: \(error.localizedDescription)")
      throw error
    }
  }

  private func parseResponse(_ text: String) throws -> ReceiptData {
    NSLog("ReceiptSorter: [LLM] Raw output from model: \(text)")

    // Robust JSON extraction: Find the first '{' and the last '}'
    var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)

    if let firstBrace = jsonString.firstIndex(of: "{"),
      let lastBrace = jsonString.lastIndex(of: "}")
    {
      // Extract everything between the first and last braces (inclusive)
      let range = firstBrace...lastBrace
      jsonString = String(jsonString[range])
    } else {
      // Fallback cleanup if braces aren't found (unlikely for valid JSON)
      jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    guard let data = jsonString.data(using: .utf8) else {
      NSLog("ReceiptSorter: [LLM] Failed to convert string to data")
      throw LocalLLMError.invalidData
    }

    do {
      let result = try JSONDecoder().decode(ReceiptData.self, from: data)
      NSLog("ReceiptSorter: [LLM] JSON decode successful")
      return result
    } catch {
      NSLog("ReceiptSorter: [LLM] JSON decode failed: \(error)")
      NSLog("ReceiptSorter: [LLM] Attempted to parse: \(jsonString)")
      throw error
    }
  }
}

// Bridges Tokenizers.AutoTokenizer (swift-transformers) to MLXLMCommon.Tokenizer.
// Replicates what the #huggingFaceTokenizerLoader() macro expands to, without requiring macros.
private struct HuggingFaceTokenizerLoader: MLXLMCommon.TokenizerLoader {
  func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
    let upstream = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
    return TokenizerBridge(upstream)
  }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
  private let upstream: any Tokenizers.Tokenizer

  init(_ upstream: any Tokenizers.Tokenizer) { self.upstream = upstream }

  func encode(text: String, addSpecialTokens: Bool) -> [Int] {
    upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
  }

  func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
    upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
  }

  func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
  func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }

  var bosToken: String? { upstream.bosToken }
  var eosToken: String? { upstream.eosToken }
  var unknownToken: String? { upstream.unknownToken }

  func applyChatTemplate(
    messages: [[String: any Sendable]],
    tools: [[String: any Sendable]]?,
    additionalContext: [String: any Sendable]?
  ) throws -> [Int] {
    do {
      return try upstream.applyChatTemplate(
        messages: messages, tools: tools, additionalContext: additionalContext)
    } catch Tokenizers.TokenizerError.missingChatTemplate {
      throw MLXLMCommon.TokenizerError.missingChatTemplate
    }
  }
}

public enum LocalLLMError: LocalizedError {
  case modelLoadFailed
  case modelNotDownloaded
  case invalidData
  case generationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .modelLoadFailed: return "Failed to load local LLM model."
    case .invalidData: return "Could not parse JSON response from local model."
    case .generationFailed(let msg): return "Generation failed: \(msg)"
    case .modelNotDownloaded: return "Model not downloaded. Please wait for download to complete."
    }
  }
}
