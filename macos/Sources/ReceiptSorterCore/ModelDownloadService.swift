import Foundation
import Hub
@preconcurrency import MLX
@preconcurrency import MLXLLM
@preconcurrency import MLXLMCommon

@available(macOS 14.0, *)
@MainActor
public class ModelDownloadService: ObservableObject {

  // MARK: - Download State

  public enum DownloadState: Equatable {
    case notStarted
    case downloading(progress: Double)
    case completed
    case failed(String)

    public static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
      switch (lhs, rhs) {
      case (.notStarted, .notStarted):
        return true
      case (.downloading(let p1), .downloading(let p2)):
        return p1 == p2
      case (.completed, .completed):
        return true
      case (.failed(let e1), .failed(let e2)):
        return e1 == e2
      default:
        return false
      }
    }
  }

  // MARK: - Published Properties

  @Published public private(set) var state: DownloadState = .notStarted
  @Published public private(set) var progress: Double = 0.0
  @Published public private(set) var downloadedBytes: Int64 = 0
  @Published public private(set) var totalBytes: Int64 = 0
  @Published public private(set) var currentModelId: String?

  // MARK: - Private Properties

  private var downloadTask: Task<Void, Never>?
  private let modelSizeEstimate: Int64 = 2_147_483_648  // ~2GB

  // MARK: - Initialization

  public init() {}

  // MARK: - Public Methods

  /// Check if a model is already downloaded
  public func isModelDownloaded(modelId: String) -> Bool {
    // Use HubApi to check for the model directory, consistent with download logic
    let repo = Hub.Repo(id: modelId)
    let modelURL = HubApi.shared.localRepoLocation(repo)

    // Check if the directory exists and has content (e.g. config.json)
    // This is a fast check compared to recursive size calculation
    let configURL = modelURL.appendingPathComponent("config.json")
    return FileManager.default.fileExists(atPath: configURL.path)
  }

  /// Start downloading the model
  public func downloadModel(modelId: String) {
    // Cancel any existing download
    downloadTask?.cancel()

    // Reset state
    state = .downloading(progress: 0.0)
    progress = 0.0
    downloadedBytes = 0
    totalBytes = modelSizeEstimate
    currentModelId = modelId

    // Start download task detached from MainActor context
    downloadTask = Task.detached { [weak self] in
      guard let self = self else { return }
      do {
        try await self.performDownload(modelId: modelId)

        await MainActor.run {
          // Mark as completed
          self.state = .completed
          self.progress = 1.0

          // Save completion state
          UserDefaults.standard.set(true, forKey: "hasCompletedModelDownload")
          UserDefaults.standard.set(modelId, forKey: "lastDownloadedModelId")
          UserDefaults.standard.set(false, forKey: "modelDownloadFailed")
        }

      } catch {
        await MainActor.run {
          // Handle download failure
          let errorMessage = error.localizedDescription

          // Provide actionable error messages for common issues
          var userFriendlyMessage = errorMessage
          if errorMessage.contains("Authentication") || errorMessage.contains("token") {
            userFriendlyMessage =
              "Authentication required. Please add your Hugging Face token in Settings (⌘,) → General."
          } else if errorMessage.contains("network") || errorMessage.contains("Network") {
            userFriendlyMessage = "Network error. Check your internet connection and try again."
          }

          self.state = .failed(userFriendlyMessage)
          UserDefaults.standard.set(true, forKey: "modelDownloadFailed")
          NSLog("ReceiptSorter: Model download failed: \(errorMessage)")
        }
      }
    }
  }

  /// Cancel ongoing download
  public func cancelDownload() {
    downloadTask?.cancel()
    downloadTask = nil
    state = .notStarted
    progress = 0.0
  }

  /// Retry failed download
  public func retryDownload() {
    if let modelId = currentModelId {
      downloadModel(modelId: modelId)
    }
  }

  // MARK: - Private Methods

  nonisolated private func performDownload(modelId: String) async throws {
    // Use HubApi to download the model (snapshot) without loading it into memory.
    let repo = Hub.Repo(id: modelId)
    let api = HubApi.shared

    // Download with progress handler
    try await api.snapshot(from: repo) { progress in
      let fraction = progress.fractionCompleted

      // Throttle updates via creating tasks on MainActor
      Task { @MainActor in
        self.progress = fraction
        self.state = .downloading(progress: fraction)
      }
    }
  }
}

// MARK: - URL Extension for Directory Size
