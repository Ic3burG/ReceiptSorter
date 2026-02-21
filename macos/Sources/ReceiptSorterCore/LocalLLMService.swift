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

@available(macOS 14.0, *)
public actor LocalLLMService: ReceiptDataExtractor {

  private let modelId: String
  private var modelContainer: ModelContainer?

  public init(modelId: String = "mlx-community/Qwen2.5-3B-Instruct-4bit") {
    self.modelId = modelId
    NSLog("ReceiptSorter: [LLM] LocalLLMService initialized with model: \(modelId)")
  }

  public func isModelReady() -> Bool {
    // Use HubApi to check for the model directory, consistent with ModelDownloadService
    let repo = Hub.Repo(id: modelId)
    let modelURL = HubApi.shared.localRepoLocation(repo)

    // Check if the directory exists and has content (e.g. config.json)
    let configURL = modelURL.appendingPathComponent("config.json")
    return FileManager.default.fileExists(atPath: configURL.path)
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
    let config = ModelConfiguration(directory: modelURL)

    NSLog("ReceiptSorter: Loading local model from: \(modelURL.path)")
    do {
      self.modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)
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

    // Simplify categories for smaller models to prevent context window overload and confusion
    let commonCategories = [
      "Groceries", "Dining", "Gas/Fuel", "Transportation", "Shopping",
      "Entertainment", "Travel", "Utilities", "Health", "Services", "Other",
    ].joined(separator: ", ")

    let systemPrompt = """
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

      Categories: \(commonCategories)

      Instructions:
      - Output ONLY valid JSON.
      - "category" must be one of the Categories list.
      - If currency is unknown, use "CAD".
      - Do not use markdown.
      """

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
      return try parseResponse(fullOutput)
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
