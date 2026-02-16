import CoreXLSX
import Foundation

/// Service for exporting receipt data to Excel (.xlsx) files
@available(macOS 13.0, *)
public actor ExcelService {
  private let fileURL: URL

  /// Column headers for the receipt spreadsheet
  private let headers = [
    "Date",
    "Vendor",
    "Description",
    "Category",
    "Amount",
    "Currency",
    "Notes",
  ]

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// Export a receipt to Excel. Creates file if it doesn't exist, appends if it does.
  public func exportReceipt(_ data: ReceiptData) async throws {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try await appendToExisting(data)
    } else {
      try await createNewSheet(with: [data])
    }
  }

  /// Append a receipt to an existing Excel file
  private func appendToExisting(_ data: ReceiptData) async throws {
    // Read existing data
    var existingRows = try await readExistingData()

    // Check for duplicates (same date, vendor, and amount)
    let newRow = createRow(from: data)
    let isDuplicate = existingRows.contains { row in
      row.count >= 5 && row[0] == newRow[0]  // Date
        && row[1] == newRow[1]  // Vendor
        && row[4] == newRow[4]  // Amount
    }

    if !isDuplicate {
      existingRows.append(newRow)
    }

    // Rewrite the file with all data
    try await writeSheet(rows: existingRows)
  }

  /// Create a new Excel file with headers and data
  public func createNewSheet(with receipts: [ReceiptData]) async throws {
    let rows = receipts.map { createRow(from: $0) }
    try await writeSheet(rows: rows)
  }

  /// Read existing data from the Excel file
  private func readExistingData() async throws -> [[String]] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return []
    }

    guard let xlsxFile = XLSXFile(filepath: fileURL.path) else {
      throw ExcelError.readFailed("Could not open file")
    }

    guard let workbook = try xlsxFile.parseWorkbooks().first,
      let sheetPath = try xlsxFile.parseWorksheetPathsAndNames(workbook: workbook).first?.path
    else {
      return []
    }

    let worksheet = try xlsxFile.parseWorksheet(at: sheetPath)

    // Get shared strings table for text lookup (optional)
    let sharedStrings = try xlsxFile.parseSharedStrings()

    var rows: [[String]] = []
    var isFirstRow = true

    worksheet.data?.rows.forEach { row in
      // Skip header row
      if isFirstRow {
        isFirstRow = false
        return
      }

      var rowData: [String] = []
      for cell in row.cells {
        if let strings = sharedStrings, let value = cell.stringValue(strings) {
          rowData.append(value)
        } else if let value = cell.value {
          rowData.append(value)
        } else {
          rowData.append("")
        }
      }
      rows.append(rowData)
    }

    return rows
  }

  /// Write all data to the Excel file
  private func writeSheet(rows: [[String]]) async throws {
    // Create XML for the worksheet
    let worksheetXML = buildWorksheetXML(headers: headers, rows: rows)
    let sharedStringsXML = buildSharedStringsXML(headers: headers, rows: rows)
    let workbookXML = buildWorkbookXML()
    let workbookRelsXML = buildWorkbookRelsXML()
    let contentTypesXML = buildContentTypesXML()
    let relsXML = buildRelsXML()

    // Create the xlsx file (which is a zip archive)
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    // Create directory structure
    let xlDir = tempDir.appendingPathComponent("xl")
    let worksheetsDir = xlDir.appendingPathComponent("worksheets")
    let relsDir = tempDir.appendingPathComponent("_rels")
    let xlRelsDir = xlDir.appendingPathComponent("_rels")

    try FileManager.default.createDirectory(at: worksheetsDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: xlRelsDir, withIntermediateDirectories: true)

    // Write files
    try worksheetXML.write(
      to: worksheetsDir.appendingPathComponent("sheet1.xml"), atomically: true, encoding: .utf8)
    try sharedStringsXML.write(
      to: xlDir.appendingPathComponent("sharedStrings.xml"), atomically: true, encoding: .utf8)
    try workbookXML.write(
      to: xlDir.appendingPathComponent("workbook.xml"), atomically: true, encoding: .utf8)
    try workbookRelsXML.write(
      to: xlRelsDir.appendingPathComponent("workbook.xml.rels"), atomically: true, encoding: .utf8)
    try contentTypesXML.write(
      to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
    try relsXML.write(
      to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)

    // Create zip archive
    let zipURL = tempDir.appendingPathComponent("output.xlsx")
    try createZipArchive(from: tempDir, to: zipURL)

    // Move to final location
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
    try FileManager.default.moveItem(at: zipURL, to: fileURL)

    // Cleanup
    try? FileManager.default.removeItem(at: tempDir)
  }

  private func createRow(from data: ReceiptData) -> [String] {
    return [
      data.date ?? "",
      data.vendor ?? "",
      data.description ?? "",
      data.category ?? "",
      data.total_amount.map { String(format: "%.2f", $0) } ?? "",
      data.currency ?? "",
      "Exported from Receipt Sorter",
    ]
  }

  // MARK: - XML Building

  private func buildWorksheetXML(headers: [String], rows: [[String]]) -> String {
    var xml = """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <sheetData>
      """

    // Header row
    xml += "<row r=\"1\">"
    for (index, _) in headers.enumerated() {
      let col = columnLetter(for: index)
      xml += "<c r=\"\(col)1\" t=\"s\"><v>\(index)</v></c>"
    }
    xml += "</row>"

    // Data rows
    for (rowIndex, row) in rows.enumerated() {
      let rowNum = rowIndex + 2  // Start after header
      xml += "<row r=\"\(rowNum)\">"
      for (colIndex, value) in row.enumerated() {
        let col = columnLetter(for: colIndex)
        let stringIndex = headers.count + (rowIndex * headers.count) + colIndex
        if !value.isEmpty {
          xml += "<c r=\"\(col)\(rowNum)\" t=\"s\"><v>\(stringIndex)</v></c>"
        }
      }
      xml += "</row>"
    }

    xml += """
      </sheetData>
      </worksheet>
      """

    return xml
  }

  private func buildSharedStringsXML(headers: [String], rows: [[String]]) -> String {
    var allStrings: [String] = headers
    for row in rows {
      allStrings.append(contentsOf: row)
    }

    let count = allStrings.count
    var xml = """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(count)" uniqueCount="\(count)">
      """

    for string in allStrings {
      let escaped = escapeXML(string)
      xml += "<si><t>\(escaped)</t></si>"
    }

    xml += "</sst>"
    return xml
  }

  private func buildWorkbookXML() -> String {
    return """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
      <sheet name="Receipts" sheetId="1" r:id="rId1"/>
      </sheets>
      </workbook>
      """
  }

  private func buildWorkbookRelsXML() -> String {
    return """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
      </Relationships>
      """
  }

  private func buildContentTypesXML() -> String {
    return """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
      </Types>
      """
  }

  private func buildRelsXML() -> String {
    return """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      </Relationships>
      """
  }

  private func columnLetter(for index: Int) -> String {
    let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if index < 26 {
      return String(letters[letters.index(letters.startIndex, offsetBy: index)])
    }
    // For columns beyond Z
    let first = index / 26 - 1
    let second = index % 26
    return String(letters[letters.index(letters.startIndex, offsetBy: first)])
      + String(letters[letters.index(letters.startIndex, offsetBy: second)])
  }

  private func escapeXML(_ string: String) -> String {
    return
      string
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&apos;")
  }

  private func createZipArchive(from sourceDir: URL, to destination: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.currentDirectoryURL = sourceDir
    process.arguments = ["-r", destination.path, "."]

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw ExcelError.zipCreationFailed
    }
  }
}

public enum ExcelError: LocalizedError {
  case fileNotConfigured
  case zipCreationFailed
  case readFailed(String)

  public var errorDescription: String? {
    switch self {
    case .fileNotConfigured:
      return "Excel file path not configured in Settings."
    case .zipCreationFailed:
      return "Failed to create Excel file."
    case .readFailed(let message):
      return "Failed to read Excel file: \(message)"
    }
  }
}
