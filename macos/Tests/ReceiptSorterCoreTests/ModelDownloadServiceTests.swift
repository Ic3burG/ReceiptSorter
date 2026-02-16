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
