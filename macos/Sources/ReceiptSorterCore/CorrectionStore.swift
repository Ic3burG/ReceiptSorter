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

public struct Correction: Codable, Identifiable, Sendable {
  public let id: UUID
  public let field: String      // "vendor" | "currency" | "category" | "date" | "description"
  public let original: String
  public let corrected: String
  public var count: Int
  public let createdAt: Date
  public var updatedAt: Date
}

public struct Rule: Codable, Identifiable, Sendable {
  public let id: UUID
  public let field: String
  public let original: String
  public let corrected: String
  public var applyCount: Int
  public let promotedAt: Date
}

private struct StoreDocument: Codable {
  var corrections: [Correction]
  var rules: [Rule]
}

@available(macOS 14.0, *)
@MainActor
public class CorrectionStore: ObservableObject {
  @Published public private(set) var corrections: [Correction] = []
  @Published public private(set) var rules: [Rule] = []

  private let storeURL: URL

  public init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("ReceiptSorter", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    storeURL = dir.appendingPathComponent("corrections.json")
    load()
  }

  // MARK: - Persistence

  private func load() {
    guard
      let data = try? Data(contentsOf: storeURL),
      let doc = try? JSONDecoder().decode(StoreDocument.self, from: data)
    else { return }
    corrections = doc.corrections
    rules = doc.rules
  }

  func save() {
    let doc = StoreDocument(corrections: corrections, rules: rules)
    guard let data = try? JSONEncoder().encode(doc) else {
      NSLog("ReceiptSorter: [CorrectionStore] Failed to encode corrections")
      return
    }
    if (try? data.write(to: storeURL, options: .atomic)) == nil {
      NSLog("ReceiptSorter: [CorrectionStore] Failed to write corrections to disk")
    }
  }
}

// MARK: - Business Logic

@available(macOS 14.0, *)
extension CorrectionStore {

  /// Records a user correction. Creates a new Correction or increments an existing one.
  /// Auto-promotes to a Rule when count reaches 3.
  public func record(field: String, original: String, corrected: String) {
    let trimmedOriginal = original.trimmingCharacters(in: .whitespaces)
    let trimmedCorrected = corrected.trimmingCharacters(in: .whitespaces)
    guard trimmedOriginal != trimmedCorrected,
      !trimmedOriginal.isEmpty,
      !trimmedCorrected.isEmpty
    else { return }

    if let idx = corrections.firstIndex(where: {
      $0.field == field
        && $0.original.lowercased() == trimmedOriginal.lowercased()
        && $0.corrected == trimmedCorrected
    }) {
      corrections[idx].count += 1
      corrections[idx].updatedAt = Date()
      let count = corrections[idx].count
      let alreadyHasRule = rules.contains {
        $0.field == field && $0.original.lowercased() == trimmedOriginal.lowercased()
      }
      if count >= 3 && !alreadyHasRule {
        rules.append(
          Rule(
            id: UUID(), field: field, original: trimmedOriginal,
            corrected: trimmedCorrected, applyCount: 0, promotedAt: Date()))
      }
    } else {
      corrections.append(
        Correction(
          id: UUID(), field: field, original: trimmedOriginal, corrected: trimmedCorrected,
          count: 1, createdAt: Date(), updatedAt: Date()))
    }
    save()
  }

  /// Returns a prompt snippet of the 5 most recent corrections, or nil if none exist.
  public func buildFewShotSnippet() -> String? {
    guard !corrections.isEmpty else { return nil }
    let lines = corrections
      .sorted { $0.updatedAt > $1.updatedAt }
      .prefix(5)
      .map { "- \($0.field): \"\($0.original)\" → \"\($0.corrected)\"" }
    return "Past corrections (apply these patterns to new receipts):\n" + lines.joined(separator: "\n")
  }

  /// Applies all Rules to an extracted ReceiptData. Returns the corrected data.
  /// Increments applyCount on each matched rule.
  public func applyRules(to data: ReceiptData) -> ReceiptData {
    guard !rules.isEmpty else { return data }
    var mutated = false

    func apply(field: String, value: String?) -> String? {
      guard let value else { return nil }
      guard let idx = rules.firstIndex(where: {
        $0.field == field && $0.original.lowercased() == value.lowercased()
      }) else { return value }
      let result = rules[idx].corrected
      rules[idx].applyCount += 1
      mutated = true
      return result
    }

    let result = ReceiptData(
      total_amount: data.total_amount,
      currency: apply(field: "currency", value: data.currency),
      date: apply(field: "date", value: data.date),
      vendor: apply(field: "vendor", value: data.vendor),
      description: apply(field: "description", value: data.description),
      category: apply(field: "category", value: data.category)
    )
    if mutated { save() }
    return result
  }

  // MARK: - Management

  public func deleteCorrection(id: UUID) {
    corrections.removeAll { $0.id == id }
    save()
  }

  public func deleteRule(id: UUID) {
    rules.removeAll { $0.id == id }
    save()
  }

  public func clearAll() {
    corrections.removeAll()
    rules.removeAll()
    save()
  }
}
