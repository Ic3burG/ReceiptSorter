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

// MARK: - Domain Model

public struct ReceiptData: Codable, Sendable, Equatable {
  public let total_amount: Double?
  public let currency: String?
  public let date: String?
  public let vendor: String?
  public let description: String?
  public let category: String?

  public init(
    total_amount: Double?, currency: String?, date: String?, vendor: String?,
    description: String?, category: String? = nil
  ) {
    self.total_amount = total_amount
    self.currency = currency
    self.date = date
    self.vendor = vendor
    self.description = description
    self.category = category
  }
}

// MARK: - Core

@available(macOS 14.0, *)
public struct ReceiptSorterCore: Sendable {
  public let ocrService: OCRService
  public let dataExtractor: ReceiptDataExtractor
  nonisolated(unsafe) public let authService: AuthService?
  public let sheetService: SheetService?
  public let excelService: ExcelService?
  public let fileOrganizationService: FileOrganizationService?
  public let correctionStore: CorrectionStore

  @MainActor
  public init(
    correctionStore: CorrectionStore = CorrectionStore(),
    clientID: String? = nil,
    clientSecret: String? = nil,
    sheetID: String? = nil,
    excelFilePath: String? = nil,
    organizationBasePath: String? = nil
  ) {
    self.correctionStore = correctionStore
    self.ocrService = OCRService()
    self.dataExtractor = LocalLLMService(
      modelId: GemmaModel.modelId, correctionStore: correctionStore)

    if let clientID = clientID, !clientID.isEmpty {
      let auth = AuthService(clientID: clientID, clientSecret: clientSecret)
      self.authService = auth
      if let sheetID = sheetID, !sheetID.isEmpty {
        self.sheetService = SheetService(authService: auth, sheetID: sheetID)
      } else {
        self.sheetService = nil
      }
    } else {
      self.authService = nil
      self.sheetService = nil
    }

    if let excelFilePath = excelFilePath, !excelFilePath.isEmpty {
      self.excelService = ExcelService(fileURL: URL(fileURLWithPath: excelFilePath))
    } else {
      self.excelService = nil
    }

    if let organizationBasePath = organizationBasePath, !organizationBasePath.isEmpty {
      self.fileOrganizationService = FileOrganizationService(
        baseDirectory: URL(fileURLWithPath: organizationBasePath))
    } else {
      self.fileOrganizationService = nil
    }
  }

  public func extractText(from fileURL: URL) async throws -> String {
    NSLog("ReceiptSorterCore: OCR starting for file")
    let result = try await ocrService.extractText(from: fileURL)
    NSLog("ReceiptSorterCore: OCR complete, got \(result.count) chars")
    return result
  }

  public func extractReceiptData(from text: String) async throws -> ReceiptData {
    NSLog("ReceiptSorterCore: extractReceiptData called")
    NSLog("ReceiptSorterCore: About to call dataExtractor.extractData...")
    let result = try await dataExtractor.extractData(from: text)
    NSLog("ReceiptSorterCore: dataExtractor.extractData completed successfully")
    return result
  }

  // MARK: - Export Methods

  public func exportToExcel(data: ReceiptData) async throws {
    guard let excelService = excelService else {
      throw ExcelError.fileNotConfigured
    }
    try await excelService.exportReceipt(data)
  }

  public func uploadToSheets(data: ReceiptData) async throws {
    guard let sheetService = sheetService else {
      throw SheetError.sheetsNotConfigured
    }
    try await sheetService.appendReceipt(data)
  }

  public func formatSheet() async throws {
    guard let sheetService = sheetService else {
      throw SheetError.sheetsNotConfigured
    }
    try await sheetService.formatHeader()
  }

  // MARK: - File Organization

  public func organizeFile(_ fileURL: URL, date: String) async throws -> URL {
    guard let service = fileOrganizationService else {
      throw FileOrganizationError.notConfigured
    }
    return try await service.organizeReceipt(fileURL, date: date)
  }
}

public enum AuthError: LocalizedError {
  case authFailed(String)
  case notAuthorized
  case tokenRefreshFailed(String)

  public var errorDescription: String? {
    switch self {
    case .authFailed(let message):
      return "Authentication failed: \(message)"
    case .notAuthorized:
      return "Not authorized. Please sign in first."
    case .tokenRefreshFailed(let message):
      return "Token refresh failed: \(message)"
    }
  }
}
