import Foundation
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
    private let modelSizeEstimate: Int64 = 2_147_483_648 // ~2GB
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Check if a model is already downloaded
    public func isModelDownloaded(modelId: String) -> Bool {
        // Get the HuggingFace cache directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let cacheDir = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
        
        // Convert model ID to cache directory name
        // e.g., "mlx-community/Llama-3.2-3B-Instruct-4bit" -> "models--mlx-community--Llama-3.2-3B-Instruct-4bit"
        let modelDirName = "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        let modelPath = cacheDir.appendingPathComponent(modelDirName)
        
        // Check if directory exists and contains files
        if FileManager.default.fileExists(atPath: modelPath.path) {
            // Check if it has substantial content (at least 500MB to avoid partial downloads)
            if let size = try? modelPath.directoryTotalSize(), size > 500_000_000 {
                return true
            }
        }
        
        return false
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
        
        // Start download task
        downloadTask = Task { @MainActor in
            do {
                try await performDownload(modelId: modelId)
                
                // Mark as completed
                state = .completed
                progress = 1.0
                
                // Save completion state
                UserDefaults.standard.set(true, forKey: "hasCompletedModelDownload")
                UserDefaults.standard.set(modelId, forKey: "lastDownloadedModelId")
                UserDefaults.standard.set(false, forKey: "modelDownloadFailed")
                
            } catch {
                // Handle download failure
                let errorMessage = error.localizedDescription
                state = .failed(errorMessage)
                UserDefaults.standard.set(true, forKey: "modelDownloadFailed")
                
                print("Model download failed: \(errorMessage)")
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
    
    private func performDownload(modelId: String) async throws {
        // Create model configuration
        let config = ModelConfiguration(id: modelId)
        
        // Get cache path to monitor progress
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let cacheDir = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
        
        let modelDirName = "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        let modelPath = cacheDir.appendingPathComponent(modelDirName)
        
        // Start monitoring progress in background
        let progressTask = Task { @MainActor in
            await monitorDownloadProgress(modelPath: modelPath)
        }
        
        // Load the model container (this triggers the download)
        _ = try await LLMModelFactory.shared.loadContainer(configuration: config)
        
        // Cancel progress monitoring
        progressTask.cancel()
        
        // Final progress update
        progress = 1.0
        state = .downloading(progress: 1.0)
    }
    
    private func monitorDownloadProgress(modelPath: URL) async {
        while !Task.isCancelled {
            do {
                // Get current size of downloaded files
                if let currentSize = try? modelPath.directoryTotalSize() {
                    downloadedBytes = currentSize
                    
                    // Calculate progress (cap at 99% until actually complete)
                    let calculatedProgress = min(Double(currentSize) / Double(totalBytes), 0.99)
                    progress = calculatedProgress
                    state = .downloading(progress: calculatedProgress)
                }
                
                // Check every 500ms
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                // Task cancelled or other error
                break
            }
        }
    }
}

// MARK: - URL Extension for Directory Size

extension URL {
    func directoryTotalSize() throws -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: self,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }
        
        return totalSize
    }
}
