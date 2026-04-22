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

  private var bannerIcon: String {
    switch downloadService.state {
    case .notStarted: return "arrow.down.circle"
    case .downloading: return "arrow.down.circle.fill"
    case .failed: return "exclamationmark.circle.fill"
    case .completed: return "checkmark.circle.fill"
    }
  }

  private var bannerColor: Color {
    switch downloadService.state {
    case .notStarted: return .orange
    case .downloading: return .accentColor
    case .failed: return .red
    case .completed: return .green
    }
  }

  private var bannerTitle: String {
    switch downloadService.state {
    case .notStarted: return "AI Model Required"
    case .downloading: return "Downloading AI Model"
    case .failed: return "Download Failed"
    case .completed: return "Model Ready"
    }
  }

  private var bannerSubtitle: String {
    switch downloadService.state {
    case .notStarted:
      return "\(GemmaModel.displayName) (~3 GB) is needed to process receipts."
    case .downloading(let progress):
      let pct = Int(progress * 100)
      let downloaded = ByteCountFormatter.string(
        fromByteCount: downloadService.downloadedBytes, countStyle: .file)
      let total = ByteCountFormatter.string(
        fromByteCount: downloadService.totalBytes, countStyle: .file)
      return "\(pct)% complete (\(downloaded) of ~\(total))"
    case .failed(let error):
      return error
    case .completed:
      return "Ready to process receipts."
    }
  }

  private var bannerSubtitleColor: Color {
    if case .failed = downloadService.state { return .red }
    return .secondary
  }

  @ViewBuilder
  private var bannerAction: some View {
    switch downloadService.state {
    case .notStarted:
      Button("Download") {
        downloadService.downloadModel(modelId: GemmaModel.modelId)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    case .failed:
      Button("Retry") {
        downloadService.retryDownload()
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    default:
      EmptyView()
    }
  }

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: bannerIcon)
          .foregroundColor(bannerColor)
          .font(.system(size: 20))

        VStack(alignment: .leading, spacing: 2) {
          Text(bannerTitle)
            .font(.headline)
            .foregroundColor(.primary)

          Text(bannerSubtitle)
            .font(.caption)
            .foregroundColor(bannerSubtitleColor)
        }

        Spacer()

        bannerAction
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
