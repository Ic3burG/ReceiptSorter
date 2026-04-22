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

@main
struct ReceiptSorterApp: App {
  @StateObject private var modelDownloadService = ModelDownloadService()
  @AppStorage("hasCompletedModelDownload") private var hasCompletedDownload = false
  @AppStorage("hfToken") private var hfToken: String = ""

  init() {
    // Set Hugging Face token environment variable if available
    // This allows HubApi to authenticate automatically
    if let token = UserDefaults.standard.string(forKey: "hfToken"), !token.isEmpty {
      setenv("HF_TOKEN", token, 1)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(modelDownloadService)
        .onAppear {
          Task {
            await checkAndDownloadModel()
          }
        }
    }
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unified)

    Settings {
      ModernSettingsView()
        .environmentObject(modelDownloadService)
    }
  }

  private func checkAndDownloadModel() async {
    // Always check whether the current model is on disk — do not gate on the
    // legacy hasCompletedDownload flag, which may be stale after a model swap.
    if !modelDownloadService.isModelDownloaded(modelId: GemmaModel.modelId) {
      modelDownloadService.downloadModel(modelId: GemmaModel.modelId)
    }
  }
}
