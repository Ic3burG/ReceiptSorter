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

/// Service for organizing receipt files into year/month folder structure
@available(macOS 13.0, *)
public actor FileOrganizationService {
    private let baseDirectoryURL: URL
    private let fileManager = FileManager.default
    
    public init(baseDirectory: URL) {
        self.baseDirectoryURL = baseDirectory
    }
    
    /// Organizes a receipt file into YYYY/MM folder structure based on the receipt date.
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
        
        // Create destination folder structure: baseDir/YYYY/MM/
        let destinationFolder = baseDirectoryURL
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
    
    /// Parses a date string in YYYY-MM-DD format and returns (year, month) tuple
    private func parseDate(_ dateString: String) -> (year: String, month: String)? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Expected format: YYYY-MM-DD
        let components = trimmed.split(separator: "-")
        guard components.count >= 2 else { return nil }
        
        let year = String(components[0])
        let month = String(components[1])
        
        // Validate year (4 digits, reasonable range)
        guard year.count == 4,
              let yearInt = Int(year),
              yearInt >= 1900 && yearInt <= 2100 else {
            return nil
        }
        
        // Validate month (1-2 digits, 01-12)
        guard let monthInt = Int(month),
              monthInt >= 1 && monthInt <= 12 else {
            return nil
        }
        
        // Format month with leading zero
        let formattedMonth = String(format: "%02d", monthInt)
        
        return (year, formattedMonth)
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
            let newFilename = ext.isEmpty
                ? "\(baseName)_\(counter)"
                : "\(baseName)_\(counter).\(ext)"
            destinationURL = folder.appendingPathComponent(newFilename)
            counter += 1
        } while fileManager.fileExists(atPath: destinationURL.path)
        
        return destinationURL
    }
}
