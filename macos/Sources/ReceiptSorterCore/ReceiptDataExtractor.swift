import Foundation

public protocol ReceiptDataExtractor: Sendable {
  func extractData(from text: String) async throws -> ReceiptData
}
