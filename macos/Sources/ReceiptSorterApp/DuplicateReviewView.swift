import ReceiptSorterCore
import SwiftUI

/// Information about a duplicate conflict for display
struct DuplicateConflict: Equatable {
  let existingURL: URL
  let newFileURL: URL
  let proposedURL: URL
  let itemIndex: Int

  static func == (lhs: DuplicateConflict, rhs: DuplicateConflict) -> Bool {
    lhs.existingURL == rhs.existingURL && lhs.newFileURL == rhs.newFileURL
      && lhs.proposedURL == rhs.proposedURL && lhs.itemIndex == rhs.itemIndex
  }
}

/// Side-by-side comparison view for reviewing duplicate receipts
struct DuplicateReviewView: View {
  let conflict: DuplicateConflict
  let existingMetadata: FileMetadata?
  let newMetadata: FileMetadata?
  let onResolution: (ConflictResolution) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.title2)
          .foregroundColor(.orange)

        VStack(alignment: .leading, spacing: 2) {
          Text("Duplicate File Detected")
            .font(.headline)
          Text("A file with similar attributes already exists.")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
      }
      .padding()
      .background(Color.orange.opacity(0.1))

      // Comparison Content
      HStack(spacing: 24) {
        // Existing File
        FilePreviewColumn(
          title: "Existing File",
          url: conflict.existingURL,
          metadata: existingMetadata,
          color: .blue
        )

        Divider()
          .overlay(Color.secondary.opacity(0.2))

        // New File
        FilePreviewColumn(
          title: "New File",
          url: conflict.newFileURL,
          metadata: newMetadata,
          color: .green
        )
      }
      .padding(24)
      .background(Color(NSColor.controlBackgroundColor))

      Divider()

      // Actions
      HStack(spacing: 16) {
        // Option 1: Keep Existing (Discard New)
        Button {
          resolveWith(.keepExisting)
        } label: {
          Label("Keep Existing", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .help("Delete the new file and keep the existing one.")

        Spacer()

        // Option 2: Keep Both (Rename New)
        Button {
          resolveWith(.keepBoth)
        } label: {
          Label("Keep Both", systemImage: "doc.on.doc")
        }
        .buttonStyle(.borderedProminent)
        .help("Keep both files. The new file will be renamed.")

        // Option 3: Replace (Overwrite)
        Button {
          resolveWith(.replaceWithNew)
        } label: {
          Label("Replace Old", systemImage: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(.bordered)
        .help("Overwrite the existing file with the new one.")
      }
      .padding()
      .background(Color(NSColor.windowBackgroundColor))
    }
    .frame(width: 900, height: 650)
  }

  private func resolveWith(_ resolution: ConflictResolution) {
    onResolution(resolution)
    dismiss()
  }
}

/// Column showing file preview and metadata
struct FilePreviewColumn: View {
  let title: String
  let url: URL
  let metadata: FileMetadata?
  let color: Color

  var body: some View {
    VStack(spacing: 16) {
      // Title Badge
      HStack {
        Circle()
          .fill(color)
          .frame(width: 8, height: 8)

        Text(title)
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()

        Image(systemName: url.pathExtension.lowercased() == "pdf" ? "doc.text" : "photo")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 4)

      // Preview
      ZStack {
        Color.black.opacity(0.05)

        if url.pathExtension.lowercased() == "pdf" {
          PDFKitRepresentedView(url: url)
        } else {
          AsyncImage(url: url) { image in
            image.resizable().aspectRatio(contentMode: .fit)
          } placeholder: {
            ProgressView()
          }
        }
      }
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.primary.opacity(0.1), lineWidth: 1)
      )
      .frame(height: 300)

      // Metadata Cards
      VStack(spacing: 12) {
        MiniDataCard(
          icon: "doc.text", label: "Filename", value: metadata?.filename ?? url.lastPathComponent)
        HStack(spacing: 12) {
          MiniDataCard(icon: "calendar", label: "Date", value: metadata?.formattedDate ?? "Unknown")
          MiniDataCard(
            icon: "internaldrive", label: "Size", value: metadata?.formattedSize ?? "Unknown")
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

/// A smaller card component for metadata display
struct MiniDataCard: View {
  let icon: String
  let label: String
  let value: String

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(Color.blue.opacity(0.1))
          .frame(width: 32, height: 32)
        Image(systemName: icon)
          .font(.caption)
          .foregroundColor(.blue)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.caption2)
          .foregroundColor(.secondary)
        Text(value)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Spacer()
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(NSColor.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    )
  }
}

#Preview {
  DuplicateReviewView(
    conflict: DuplicateConflict(
      existingURL: URL(fileURLWithPath: "/tmp/receipt.pdf"),
      newFileURL: URL(fileURLWithPath: "/tmp/new_receipt.pdf"),
      proposedURL: URL(fileURLWithPath: "/tmp/receipt.pdf"),
      itemIndex: 0
    ),
    existingMetadata: nil,
    newMetadata: nil,
    onResolution: { _ in }
  )
}
