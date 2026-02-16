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
