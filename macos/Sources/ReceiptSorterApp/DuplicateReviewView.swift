import SwiftUI
import ReceiptSorterCore

/// Information about a duplicate conflict for display
struct DuplicateConflict: Equatable {
    let existingURL: URL
    let newFileURL: URL
    let proposedURL: URL
    let itemIndex: Int
    
    static func == (lhs: DuplicateConflict, rhs: DuplicateConflict) -> Bool {
        lhs.existingURL == rhs.existingURL &&
        lhs.newFileURL == rhs.newFileURL &&
        lhs.proposedURL == rhs.proposedURL &&
        lhs.itemIndex == rhs.itemIndex
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
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Potential Duplicate Detected")
                    .font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            
            Divider()
            
            // Side-by-side comparison
            HStack(spacing: 0) {
                // Existing file (left)
                FilePreviewColumn(
                    title: "Existing File",
                    url: conflict.existingURL,
                    metadata: existingMetadata,
                    badgeColor: .blue
                )
                
                Divider()
                
                // New file (right)
                FilePreviewColumn(
                    title: "New File",
                    url: conflict.newFileURL,
                    metadata: newMetadata,
                    badgeColor: .green
                )
            }
            .frame(minHeight: 400)
            
            Divider()
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: { resolveWith(.keepExisting) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left.circle")
                            .font(.title2)
                        Text("Keep Existing")
                            .font(.caption)
                    }
                    .frame(width: 100)
                }
                .buttonStyle(.bordered)
                .help("Keep the existing file. The new file stays in its original location.")
                
                Button(action: { resolveWith(.keepBoth) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.title2)
                        Text("Keep Both")
                            .font(.caption)
                    }
                    .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)
                .help("Keep both files. The new file will be renamed with a unique suffix.")
                
                Button(action: { resolveWith(.replaceWithNew) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.title2)
                        Text("Replace")
                            .font(.caption)
                    }
                    .frame(width: 100)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .help("Replace the existing file with the new one. The existing file will be deleted.")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 800, height: 550)
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
    let badgeColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Title badge
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(badgeColor)
                .cornerRadius(4)
                .padding(.top, 12)
            
            // Preview
            ZStack {
                Color(NSColor.controlBackgroundColor)
                
                if url.pathExtension.lowercased() == "pdf" {
                    PDFKitRepresentedView(url: url)
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            
            // Metadata
            VStack(alignment: .leading, spacing: 6) {
                MetadataRow(icon: "doc", label: "Name", value: metadata?.filename ?? url.lastPathComponent)
                MetadataRow(icon: "calendar", label: "Modified", value: metadata?.formattedDate ?? "Unknown")
                MetadataRow(icon: "internaldrive", label: "Size", value: metadata?.formattedSize ?? "Unknown")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Single row of file metadata
struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label + ":")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
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
