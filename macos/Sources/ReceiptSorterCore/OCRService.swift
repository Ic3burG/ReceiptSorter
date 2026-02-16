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

import CoreImage
import Foundation
import PDFKit
import Vision

@available(macOS 13.0, *)
public final class OCRService: Sendable {

  public init() {}

  public func extractText(from fileURL: URL) async throws -> String {
    let fileExtension = fileURL.pathExtension.lowercased()

    if fileExtension == "pdf" {
      return try await extractTextFromPDF(at: fileURL)
    } else {
      return try await extractTextFromImage(at: fileURL)
    }
  }

  private func extractTextFromImage(at fileURL: URL) async throws -> String {
    guard let ciImage = CIImage(contentsOf: fileURL) else {
      throw OCRError.invalidImage
    }
    return try await performRecognition(on: ciImage)
  }

  private func extractTextFromPDF(at fileURL: URL) async throws -> String {
    guard let pdfDocument = PDFDocument(url: fileURL) else {
      throw OCRError.invalidPDF
    }

    var fullText = ""
    let pageCount = pdfDocument.pageCount

    for i in 0..<pageCount {
      guard let page = pdfDocument.page(at: i) else { continue }

      if let pageText = page.string, pageText.count > 10 {
        fullText += pageText + "\n"
      } else {
        let bounds = page.bounds(for: .mediaBox)
        if let nsImage = page.thumbnail(of: bounds.size, for: .mediaBox).cgImage(
          forProposedRect: nil, context: nil, hints: nil)
        {
          let ciImage = CIImage(cgImage: nsImage)
          fullText += try await performRecognition(on: ciImage) + "\n"
        }
      }
    }

    return fullText
  }

  private func performRecognition(on image: CIImage) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      let request = VNRecognizeTextRequest { request, error in
        if let error = error {
          continuation.resume(throwing: error)
          return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
          continuation.resume(returning: "")
          return
        }

        let recognizedText = observations.compactMap { observation in
          return observation.topCandidates(1).first?.string
        }.joined(separator: "\n")

        continuation.resume(returning: recognizedText)
      }

      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true

      let handler = VNImageRequestHandler(ciImage: image, options: [:])

      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

public enum OCRError: LocalizedError {
  case invalidImage
  case invalidPDF
  case recognitionFailed(String)

  public var errorDescription: String? {
    switch self {
    case .invalidImage:
      return "Invalid image file"
    case .invalidPDF:
      return "Invalid PDF file"
    case .recognitionFailed(let message):
      return "OCR recognition failed: \(message)"
    }
  }
}
