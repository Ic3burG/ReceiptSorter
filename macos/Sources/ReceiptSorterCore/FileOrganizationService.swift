import Foundation

/// Errors that can occur during file organization
public enum FileOrganizationError: LocalizedError {
  case notConfigured
  case invalidDate(String)
  case fileNotFound(URL)
  case moveFailed(String)

  public var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "File organization is not configured. Please set a base folder in Settings."
    case .invalidDate(let date):
      return "Cannot organize file: invalid or missing date '\(date)'"
    case .fileNotFound(let url):
      return "File not found: \(url.lastPathComponent)"
    case .moveFailed(let reason):
      return "Failed to move file: \(reason)"
    }
  }
}

/// Result of a file organization attempt
public enum OrganizationResult: Sendable {
  /// File was successfully moved to the new location
  case success(newURL: URL)
  /// A file with the same name already exists at the destination
  case conflict(existingURL: URL, proposedURL: URL)
  /// File was skipped for a reason (e.g., invalid date)
  case skipped(reason: String)
}

/// User's decision when resolving a duplicate conflict
public enum ConflictResolution: Sendable {
  /// Keep the existing file, don't move the new one
  case keepExisting
  /// Keep both files - move new file with unique suffix
  case keepBoth
  /// Replace existing file with the new one
  case replaceWithNew
}

/// Service for organizing receipt files into year/month folder structure
@available(macOS 13.0, *)
public actor FileOrganizationService {
  private let baseDirectoryURL: URL
  private let fileManager = FileManager.default

  public init(baseDirectory: URL) {
    self.baseDirectoryURL = baseDirectory
  }

  /// Organizes a receipt file into YYYY/mm - MMM yyyy folder structure, auto-resolving conflicts.
  /// - Parameters:
  ///   - fileURL: The URL of the file to organize
  ///   - date: The receipt date in YYYY-MM-DD format
  /// - Returns: The new file URL after moving
  /// - Throws: FileOrganizationError if the operation fails
  public func organizeReceipt(_ fileURL: URL, date: String) async throws -> URL {
    // Validate file exists
    guard fileManager.fileExists(atPath: fileURL.path) else {
      throw FileOrganizationError.fileNotFound(fileURL)
    }

    // Parse the date to extract year and month
    guard let (year, month) = parseDate(date) else {
      throw FileOrganizationError.invalidDate(date)
    }

    // Create destination folder structure: baseDir/YYYY/mm - MMM yyyy/
    let destinationFolder =
      baseDirectoryURL
      .appendingPathComponent(year, isDirectory: true)
      .appendingPathComponent(month, isDirectory: true)

    // Create directories if they don't exist
    try createDirectoryIfNeeded(destinationFolder)

    // Generate unique destination filename
    let destinationURL = generateUniqueDestination(
      folder: destinationFolder,
      filename: fileURL.lastPathComponent
    )

    // Move the file
    do {
      try fileManager.moveItem(at: fileURL, to: destinationURL)
      return destinationURL
    } catch {
      throw FileOrganizationError.moveFailed(error.localizedDescription)
    }
  }

  /// Organizes a receipt file with conflict detection (does not auto-resolve duplicates).
  /// - Parameters:
  ///   - fileURL: The URL of the file to organize
  ///   - date: The receipt date in YYYY-MM-DD format
  /// - Returns: OrganizationResult indicating success, conflict, or skipped
  public func organizeReceiptWithConflictDetection(_ fileURL: URL, date: String) async throws
    -> OrganizationResult
  {
    // Validate file exists
    guard fileManager.fileExists(atPath: fileURL.path) else {
      throw FileOrganizationError.fileNotFound(fileURL)
    }

    // Parse the date to extract year and month
    guard let (year, month) = parseDate(date) else {
      return .skipped(reason: "Invalid or missing date: \(date)")
    }

    // Create destination folder structure: baseDir/YYYY/mm - MMM yyyy/
    let destinationFolder =
      baseDirectoryURL
      .appendingPathComponent(year, isDirectory: true)
      .appendingPathComponent(month, isDirectory: true)

    // Create directories if they don't exist
    try createDirectoryIfNeeded(destinationFolder)

    // Check for existing file with same name
    let proposedURL = destinationFolder.appendingPathComponent(fileURL.lastPathComponent)

    if fileManager.fileExists(atPath: proposedURL.path) {
      // Conflict detected - return info for user review
      return .conflict(existingURL: proposedURL, proposedURL: proposedURL)
    }

    // No conflict - move the file
    do {
      try fileManager.moveItem(at: fileURL, to: proposedURL)
      return .success(newURL: proposedURL)
    } catch {
      throw FileOrganizationError.moveFailed(error.localizedDescription)
    }
  }

  /// Resolves a duplicate conflict based on user's decision.
  /// - Parameters:
  ///   - sourceURL: The source file URL to organize
  ///   - existingURL: The existing file at the destination
  ///   - resolution: User's chosen resolution
  /// - Returns: The final file URL (or nil if keeping existing)
  public func resolveConflict(
    sourceURL: URL,
    existingURL: URL,
    resolution: ConflictResolution
  ) async throws -> URL? {
    switch resolution {
    case .keepExisting:
      // Don't move the new file, return nil to indicate no change
      return nil

    case .keepBoth:
      // Generate unique name and move
      let folder = existingURL.deletingLastPathComponent()
      let uniqueURL = generateUniqueDestination(
        folder: folder, filename: sourceURL.lastPathComponent)
      try fileManager.moveItem(at: sourceURL, to: uniqueURL)
      return uniqueURL

    case .replaceWithNew:
      // Delete existing file, then move new file
      try fileManager.removeItem(at: existingURL)
      try fileManager.moveItem(at: sourceURL, to: existingURL)
      return existingURL
    }
  }

  /// Gets file metadata for display in comparison UI
  public func getFileMetadata(_ url: URL) -> FileMetadata? {
    guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
      return nil
    }

    let size = attributes[.size] as? Int64 ?? 0
    let modificationDate = attributes[.modificationDate] as? Date

    return FileMetadata(
      url: url,
      filename: url.lastPathComponent,
      size: size,
      modificationDate: modificationDate
    )
  }

  // MARK: - Private Helpers

  /// Parses a date string in YYYY-MM-DD format and returns (year, monthFolder) tuple
  /// Month folder is formatted as "mm - MMM yyyy" (e.g., "01 - January 2026")
  private func parseDate(_ dateString: String) -> (year: String, monthFolder: String)? {
    let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)

    // Expected format: YYYY-MM-DD
    let components = trimmed.split(separator: "-")
    guard components.count >= 3 else { return nil }

    let year = String(components[0])
    let month = String(components[1])
    let day = String(components[2])

    // Validate year (4 digits, reasonable range)
    guard year.count == 4,
      let yearInt = Int(year),
      yearInt >= 1900 && yearInt <= 2100
    else {
      return nil
    }

    // Validate month (1-2 digits, 01-12)
    guard let monthInt = Int(month),
      monthInt >= 1 && monthInt <= 12
    else {
      return nil
    }

    // Create a Date object from the components
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let date = dateFormatter.date(from: "\(year)-\(month)-\(day)") else {
      return nil
    }

    // Format month folder as "mm - MMM yyyy"
    let monthFormatter = DateFormatter()
    monthFormatter.dateFormat = "MM - MMMM yyyy"
    let monthFolder = monthFormatter.string(from: date)

    return (year, monthFolder)
  }

  /// Creates directory at the specified URL if it doesn't exist
  private func createDirectoryIfNeeded(_ url: URL) throws {
    if !fileManager.fileExists(atPath: url.path) {
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }

  /// Generates a unique destination URL, handling filename collisions
  private func generateUniqueDestination(folder: URL, filename: String) -> URL {
    var destinationURL = folder.appendingPathComponent(filename)

    // If file doesn't exist, use the original name
    guard fileManager.fileExists(atPath: destinationURL.path) else {
      return destinationURL
    }

    // File exists, generate unique name with suffix
    let baseName = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension
    var counter = 1

    repeat {
      let newFilename =
        ext.isEmpty
        ? "\(baseName)_\(counter)"
        : "\(baseName)_\(counter).\(ext)"
      destinationURL = folder.appendingPathComponent(newFilename)
      counter += 1
    } while fileManager.fileExists(atPath: destinationURL.path)

    return destinationURL
  }
}

/// Metadata about a file for display in comparison UI
public struct FileMetadata: Sendable {
  public let url: URL
  public let filename: String
  public let size: Int64
  public let modificationDate: Date?

  public init(url: URL, filename: String, size: Int64, modificationDate: Date?) {
    self.url = url
    self.filename = filename
    self.size = size
    self.modificationDate = modificationDate
  }

  /// Formatted file size string (e.g., "245 KB")
  public var formattedSize: String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
  }

  /// Formatted modification date string
  public var formattedDate: String {
    guard let date = modificationDate else { return "Unknown" }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
