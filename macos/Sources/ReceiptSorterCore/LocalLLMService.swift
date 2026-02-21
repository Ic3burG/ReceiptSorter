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
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM

@available(macOS 14.0, *)
public actor LocalLLMService: ReceiptDataExtractor {

  private let modelId: String
  private var modelContainer: VLMModelContainer?

  public init(modelId: String = "mlx-community/Qwen2.5-VL-3B-Instruct-4bit") {
    self.modelId = modelId
    NSLog("ReceiptSorter: [VLM] LocalLLMService initialized with model: \(modelId)")
  }

  public func isModelReady() -> Bool {
    let repo = Hub.Repo(id: modelId)
    let modelURL = HubApi.shared.localRepoLocation(repo)
    let configURL = modelURL.appendingPathComponent("config.json")
    return FileManager.default.fileExists(atPath: configURL.path)
  }

  private func ensureModelLoaded() async throws {
    if modelContainer != nil { return }

    guard isModelReady() else {
      throw LocalLLMError.modelNotDownloaded
    }

    let repo = Hub.Repo(id: modelId)
    let modelURL = HubApi.shared.localRepoLocation(repo)
    let config = ModelConfiguration(directory: modelURL)

    NSLog("ReceiptSorter: Loading local VLM model from: \(modelURL.path)")
    do {
      self.modelContainer = try await VLMModelFactory.shared.loadContainer(configuration: config)
      NSLog("ReceiptSorter: VLM model container loaded successfully.")
    } catch {
      NSLog("ReceiptSorter: CRITICAL - Failed to load VLM model container: \(error.localizedDescription)")
      throw error
    }
  }

  public func extractData(from text: String) async throws -> ReceiptData {
    // Fallback or specific text-only extraction using VLM
    let userPrompt = "Extract receipt data from this text: \(text)"
    return try await process(prompt: userPrompt, imageURL: nil)
  }

  public func extractData(from imageURL: URL) async throws -> ReceiptData {
    let userPrompt = "Extract data from this receipt image."
    return try await process(prompt: userPrompt, imageURL: imageURL)
  }

  private func process(prompt: String, imageURL: URL?) async throws -> ReceiptData {
    try await ensureModelLoaded()

    guard let modelContainer = modelContainer else {
      throw LocalLLMError.modelLoadFailed
    }

    let systemPrompt = """
      You are a receipt scanner AI. Extract data from the receipt into JSON.

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
      """

    let chat: [Chat.Message] = [
      .system(systemPrompt),
      .user(prompt)
    ]

    let userInput = UserInput(chat: chat, images: imageURL.map { [.url($0)] } ?? [])

    do {
      let input = try await modelContainer.prepare(input: userInput)
      let parameters = GenerateParameters(maxTokens: 1024, temperature: 0.1)
      let stream = try await modelContainer.generate(input: input, parameters: parameters)

      var fullOutput = ""
      for await event in stream {
        if case .chunk(let text) = event {
          fullOutput += text
        }
      }

      return try parseResponse(fullOutput)
    } catch {
      NSLog("ReceiptSorter: VLM Generation failed: \(error.localizedDescription)")
      throw error
    }
  }

  private func parseResponse(_ text: String) throws -> ReceiptData {
    var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)

    // Handle DeepSeek-style thinking if present (unlikely in Qwen-VL but good for robustness)
    if let range = jsonString.range(of: "</think>") {
        jsonString = String(jsonString[range.upperBound...])
    }

    if let firstBrace = jsonString.firstIndex(of: "{"),
      let lastBrace = jsonString.lastIndex(of: "}")
    {
      let range = firstBrace...lastBrace
      jsonString = String(jsonString[range])
    }

    guard let data = jsonString.data(using: .utf8) else {
      throw LocalLLMError.invalidData
    }

    return try JSONDecoder().decode(ReceiptData.self, from: data)
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
    case .modelNotDownloaded: return "Model not downloaded."
    }
  }
}
