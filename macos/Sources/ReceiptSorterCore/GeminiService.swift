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

public struct ReceiptData: Codable, Sendable, Equatable {
  public let total_amount: Double?
  public let currency: String?
  public let date: String?
  public let vendor: String?
  public let description: String?
  public let category: String?

  public init(
    total_amount: Double?, currency: String?, date: String?, vendor: String?, description: String?,
    category: String? = nil
  ) {
    self.total_amount = total_amount
    self.currency = currency
    self.date = date
    self.vendor = vendor
    self.description = description
    self.category = category
  }
}

struct GeminiRequest: Codable, Sendable {
  let contents: [GeminiContent]
}

struct GeminiContent: Codable, Sendable {
  let parts: [GeminiPart]
}

struct GeminiPart: Codable, Sendable {
  let text: String
}

struct GeminiResponse: Codable, Sendable {
  let candidates: [GeminiCandidate]?
  let error: GeminiAPIError?
}

struct GeminiCandidate: Codable, Sendable {
  let content: GeminiContent
  let finishReason: String?
}

struct GeminiAPIError: Codable, Sendable {
  let code: Int
  let message: String
  let status: String
}

@available(macOS 13.0, *)
public actor GeminiService: ReceiptDataExtractor {
  private let apiKey: String
  private let modelName = "gemini-2.0-flash"

  public init(apiKey: String) {
    self.apiKey = apiKey
  }

  public func extractData(from text: String) async throws -> ReceiptData {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw GeminiError.emptyInput
    }

    let endpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"

    guard let url = URL(string: endpoint) else {
      throw GeminiError.apiError("Invalid API URL")
    }

    let canadianCategories = TaxCategories.canadian.joined(separator: ", ")
    let usCategories = TaxCategories.us.joined(separator: ", ")

    let promptText = """
      Extract the following information from this receipt text and return it as a JSON object:

      Required fields:
      - total_amount: The total amount paid (numeric value only, no currency symbols)
      - currency: Currency code in ISO 4217 format (e.g., CAD, USD, EUR, GBP)
      - date: Transaction date in YYYY-MM-DD format
      - vendor: Name of the merchant/vendor
      - description: Brief description of items/services purchased (1-2 sentences max)
      - category: The best matching tax category from the provided lists

      Receipt text:
      \(text)

      Tax Categories:
      - Canadian Categories: \(canadianCategories)
      - US Categories: \(usCategories)

      Important instructions:
      1. For currency detection, look for currency symbols ($, €, £, ¥), currency codes, or infer from vendor location/language
      2. If the vendor appears to be Canadian or mentions CAD, use CAD as currency
      3. For the date, try multiple formats and convert to YYYY-MM-DD
      4. For total amount, use the final total after all taxes and fees
      5. If any field cannot be determined, use null.
      6. Determine the currency first.
      7. If the currency is USD, choose the category from the "US Categories" list.
      8. If the currency is CAD or anything else, choose the category from the "Canadian Categories" list.

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

    if let httpResponse = response as? HTTPURLResponse,
      !(200...299).contains(httpResponse.statusCode)
    {
      if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data),
        let apiError = errorResponse.error
      {
        throw GeminiError.apiError("Google Error \(apiError.code): \(apiError.message)")
      }
      throw GeminiError.apiError("HTTP Error \(httpResponse.statusCode)")
    }

    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

    guard let candidate = geminiResponse.candidates?.first,
      let textPart = candidate.content.parts.first
    else {
      throw GeminiError.noResponse
    }

    return try parseResponse(textPart.text)
  }

  public func extractData(from imageURL: URL) async throws -> ReceiptData {
    // Placeholder: In a real implementation, we would send the image bytes to Gemini
    throw GeminiError.apiError("Image-based extraction not yet implemented for GeminiService")
  }

  private func parseResponse(_ text: String) throws -> ReceiptData {
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
    case .noResponse: return "Gemini returned no text."
    case .invalidData: return "Could not parse JSON response."
    case .emptyInput: return "OCR extracted no text."
    case .apiError(let message): return message
    }
  }
}
