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

import XCTest

@testable import ReceiptSorterCore

@MainActor
final class ModelDownloadServiceTests: XCTestCase {

  var service: ModelDownloadService!

  override func setUp() async throws {
    service = ModelDownloadService()
    // Reset UserDefaults for testing
    UserDefaults.standard.removeObject(forKey: "hasCompletedModelDownload")
    UserDefaults.standard.removeObject(forKey: "lastDownloadedModelId")
    UserDefaults.standard.removeObject(forKey: "modelDownloadFailed")
  }

  func testInitialState() {
    XCTAssertEqual(service.state, .notStarted)
    XCTAssertEqual(service.progress, 0.0)
  }

  func testIsModelDownloaded_WhenFilesMissing_ReturnsFalse() {
    // Use a fake model ID that definitely doesn't exist
    let fakeModelId = "fake-community/non-existent-model-123"
    XCTAssertFalse(service.isModelDownloaded(modelId: fakeModelId))
  }

  func testDownloadModel_UpdatesStateToDownloading() {
    let fakeModelId = "test/model"

    service.downloadModel(modelId: fakeModelId)

    // State should be downloading immediately
    if case .downloading(let progress) = service.state {
      XCTAssertEqual(progress, 0.0)
    } else {
      XCTFail("State should be downloading, got \(service.state)")
    }

    XCTAssertEqual(service.currentModelId, fakeModelId)
  }

  func testCancelDownload_ResetsState() {
    let fakeModelId = "test/model"
    service.downloadModel(modelId: fakeModelId)

    service.cancelDownload()

    XCTAssertEqual(service.state, .notStarted)
    XCTAssertEqual(service.progress, 0.0)
  }

  func testRetryDownload_RestartDownload() {
    let fakeModelId = "test/model"
    service.downloadModel(modelId: fakeModelId)
    service.cancelDownload()

    // Retry should restart
    service.retryDownload()

    if case .downloading = service.state {
      XCTAssertEqual(service.currentModelId, fakeModelId)
    } else {
      XCTFail("State should be downloading after retry, got \(service.state)")
    }
  }
}
