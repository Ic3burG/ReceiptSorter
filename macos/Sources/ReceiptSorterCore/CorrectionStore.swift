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
