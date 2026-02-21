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
  @AppStorage("useLocalLLM") private var localLLMEnabled = false
  @AppStorage("hasCompletedModelDownload") private var hasCompletedDownload = false
  @AppStorage("localModelId") private var localModelId: String =
    "mlx-community/Qwen2.5-3B-Instruct-4bit"
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
    // Only trigger if local LLM is enabled and we haven't completed download yet
    // OR if the user switched models and we need to download the new one (handled by download service checks)
    guard localLLMEnabled else { return }

    // We check if it's already downloaded in the service
    // If not, we start the download
    if !modelDownloadService.isModelDownloaded(modelId: localModelId) && !hasCompletedDownload {
      modelDownloadService.downloadModel(modelId: localModelId)
    }
  }
}
