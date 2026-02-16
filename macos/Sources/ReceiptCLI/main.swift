import Foundation
import ReceiptSorterCore

@MainActor
func main() async {
  // Simple argument parsing
  let args = CommandLine.arguments

  guard args.count > 1 else {
    print("Usage: receipt-cli <path-to-receipt>")
    exit(1)
  }

  let filePath = args[1]
  let fileURL = URL(fileURLWithPath: filePath)

  print("📄 Processing: \(fileURL.lastPathComponent)")

  do {
    let core = ReceiptSorterCore()
    let text = try await core.extractText(from: fileURL)

    print("\n--- Extracted Text ---")
    print(text)
    print("----------------------")
    print("✅ OCR Complete")

  } catch {
    print("❌ Error: \(error)")
    exit(1)
  }
}
await main()
