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

import ReceiptSorterCore
import SwiftUI

struct ModelDownloadBanner: View {
  @ObservedObject var downloadService: ModelDownloadService
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: "arrow.down.circle.fill")
          .foregroundColor(.accentColor)
          .font(.system(size: 20))

        VStack(alignment: .leading, spacing: 2) {
          Text("Downloading AI Model")
            .font(.headline)
            .foregroundColor(.primary)

          if case .downloading(let progress) = downloadService.state {
            let percentage = Int(progress * 100)
            let downloaded = ByteCountFormatter.string(
              fromByteCount: downloadService.downloadedBytes, countStyle: .file)
            let total = ByteCountFormatter.string(
              fromByteCount: downloadService.totalBytes, countStyle: .file)
            Text("\(percentage)% complete (\(downloaded) of ~\(total))")
              .font(.caption)
              .foregroundColor(.secondary)
          } else if case .failed(let error) = downloadService.state {
            Text("Download failed: \(error)")
              .font(.caption)
              .foregroundColor(.red)
          } else {
            Text("Preparing download...")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        if case .failed = downloadService.state {
          Button("Retry") {
            // Assuming the service will have the model ID stored or passed in
            // For now, we might need to handle this via the parent or store the ID in service
            // TODO: Wire up retry properly with model ID
            // downloadService.retryDownload(modelId: ...)
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      }

      if case .downloading(let progress) = downloadService.state {
        ProgressView(value: progress, total: 1.0)
          .progressViewStyle(.linear)
      }
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(nsColor: .windowBackgroundColor))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
    )
    .padding(.horizontal)
    .padding(.top, 8)
    .transition(.move(edge: .top).combined(with: .opacity))
  }
}
