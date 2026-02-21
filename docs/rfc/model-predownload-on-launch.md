# Model Pre-download on First Launch Plan

## Problem Statement

Currently, the Receipt Sorter app downloads the local LLM model (~2GB) on **first use** rather than **first launch**. This creates a poor user experience where:

- Users must wait for the download when they attempt to process their first receipt
- There's no clear indication of download progress during this critical moment
- The download blocks receipt processing until complete
- Users may be confused why processing takes so long the first time

## Proposed Solution

Implement a background model pre-download system that:

1. **Detects first launch** and determines if the model needs to be downloaded
2. **Downloads in the background** on app launch without blocking the UI
3. **Shows progress indication** with download status and estimated time
4. **Gracefully handles interruptions** (app quit, network loss, etc.)
5. **Falls back to on-demand download** if pre-download is skipped or failed

---

## User Review Required

> [!IMPORTANT]  
> **User Interaction Design Decision**
>
> During first launch when the model is downloading, users have several options:
>
> **Option A: Blocking Modal (Recommended)**
>
> - Show a modal sheet with download progress that users can't dismiss
> - Disable receipt processing until download completes
> - Clearest UX: users understand they must wait
> - Pro: No confusion, no error states to handle
> - Con: Forces users to wait before using the app
>
> **Option B: Non-blocking Banner**
>
> - Show a banner at the top with download progress
> - Allow users to explore the app but disable LLM-dependent features
> - More flexible but requires careful state management
> - Pro: Users can configure settings while waiting
> - Con: Must handle attempts to process receipts during download
>
> **Option C: Optional Download**
>
> - Show download prompt with "Download Now" or "Download Later" options
> - If skipped, download on first use (current behavior)
> - Pro: Fastest path to using the app (if using Gemini API)
> - Con: Reintroduces the original UX issue for local LLM users
>
> **Recommendation**: Option A for simplicity and clarity, but would like user feedback.
>
> [!WARNING]  
> **Architecture Change Required**
>
> The current `LocalLLMService` is an `actor` that lazy-loads the model. We'll need to:
>
> - Create a new `ModelDownloadService` to manage downloads independently
> - Add download progress tracking to MLX/MLXLLM (if not already available)
> - Store download state in UserDefaults to persist across app launches
>
> This is a moderate refactoring effort but maintains separation of concerns.

---

## Proposed Changes

### Core Services

#### [NEW] [ModelDownloadService.swift](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterCore/ModelDownloadService.swift)

New service to handle model download orchestration:

```swift
public actor ModelDownloadService {
    // Download state management
    public enum DownloadState {
        case notStarted
        case downloading(progress: Double)
        case completed
        case failed(Error)
    }

    // Check if model is already downloaded
    public func isModelDownloaded(modelId: String) async -> Bool

    // Start background download
    public func downloadModel(modelId: String) async throws

    // Get current download progress (0.0 to 1.0)
    public func downloadProgress() async -> Double

    // Observable state for UI binding
    @Published public var state: DownloadState
}
```

**Key responsibilities:**

- Check if model files exist locally using MLX cache paths
- Trigger model download via MLX's `LLMModelFactory.shared.loadContainer()`
- Monitor download progress (investigate MLX progress callbacks)
- Handle errors and retry logic
- Store completion state in UserDefaults

---

#### [MODIFY] [LocalLLMService.swift](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterCore/LocalLLMService.swift)

Update to work with pre-downloaded models:

**Changes:**

- Add `isModelReady() async -> Bool` public method
- Keep existing `ensureModelLoaded()` as fallback for on-demand loading
- Add error state for "model not downloaded" vs "model failed to load"

**Lines to modify:**

- L16-21: `ensureModelLoaded()` - add check for pre-downloaded model
- L23-28: `extractData()` - improve error messaging when model unavailable

---

### UI Components

#### [NEW] [ModelDownloadView.swift](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterApp/ModelDownloadView.swift)

New SwiftUI view for download progress indication:

```swift
struct ModelDownloadView: View {
    @ObservedObject var downloadService: ModelDownloadService

    var body: some View {
        VStack {
            Text("Downloading Local LLM Model...")
            ProgressView(value: downloadService.progress, total: 1.0)
            Text("~2GB - \(Int(downloadService.progress * 100))% complete")

            // Optional: Cancel/Skip button (if using Option B or C)
        }
    }
}
```

**Features:**

- Circular or linear progress indicator
- Download size and percentage
- Estimated time remaining (optional)
- Visual polish matching app design language

---

#### [MODIFY] [ReceiptSorterApp.swift](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterApp/ReceiptSorterApp.swift)

Add app launch logic to trigger download:

**Changes:**

- Add `@StateObject var modelDownloadService = ModelDownloadService()`
- Add `.onAppear` modifier to trigger download check on first launch
- Pass `modelDownloadService` to ContentView via environment

**Implementation:**

```swift
@main
struct ReceiptSorterApp: App {
    @StateObject private var modelDownloadService = ModelDownloadService()
    @AppStorage("localLLMEnabled") private var localLLMEnabled = false
    @AppStorage("hasCompletedModelDownload") private var hasCompletedDownload = false

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
        Settings {
            ModernSettingsView()
        }
    }

    private func checkAndDownloadModel() async {
        guard localLLMEnabled && !hasCompletedDownload else { return }

        // Trigger download
        await modelDownloadService.downloadModel(modelId: "...")
    }
}
```

---

#### [MODIFY] [ContentView.swift](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterApp/ContentView.swift)

Integrate download UI and handle states:

**Changes based on chosen UI option:**

**If Option A (Modal):**

- Add `.sheet(isPresented: $showingDownload)` with `ModelDownloadView`
- Show modal when `modelDownloadService.state == .downloading`
- Disable receipt processing buttons while downloading

**If Option B (Banner):**

- Add banner view at top of window when `state == .downloading`
- Allow navigation but show tooltip on disabled LLM features

**If Option C (Optional):**

- Show alert on first launch with "Download Now" / "Later" options
- Only show progress if user chooses "Download Now"

**Lines to modify:**

- L332: `initializeCore()` - check model ready state before creating `LocalLLMService`
- L958: Update help text from "downloaded on first use" to "ready to use"
- Add state binding for download progress UI

---

#### [MODIFY] [ModernSettingsView.swift](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterApp/ModernSettingsView.swift)

Update settings to show model download status:

**Changes:**

- Add download status indicator next to model selection
- Show model size on disk if downloaded
- Add "Re-download Model" button if download failed
- Update help text at L111 to reflect new download behavior

**New UI elements:**

```swift
HStack {
    Label("Model Status", systemImage: "checkmark.circle.fill")
        .foregroundColor(.green) // if downloaded
    Text("Ready (2.1 GB)")
}

// Or if downloading:
HStack {
    ProgressView()
    Text("Downloading model...")
}
```

---

### Persistence Layer

#### [MODIFY] UserDefaults Keys

Add new keys to track download state:

```swift
// In ContentView.swift or shared constants
@AppStorage("hasCompletedModelDownload") private var hasCompletedDownload = false
@AppStorage("lastModelId") private var lastDownloadedModelId = ""
@AppStorage("modelDownloadFailed") private var downloadFailed = false
```

**Purpose:**

- `hasCompletedModelDownload`: Prevent re-downloading on subsequent launches
- `lastModelId`: Track which model was downloaded (if user changes model selection)
- `modelDownloadFailed`: Remember failed download to prompt user

---

## Technical Considerations

### MLX Download Progress

**Investigation needed:**

- MLX's `LLMModelFactory.shared.loadContainer()` likely downloads from HuggingFace Hub
- Need to determine if MLX exposes download progress callbacks
- If not available, may need to:
  - Monitor cache directory size
  - Estimate progress based on known model size
  - Or show indeterminate progress

**Fallback approach:**

```swift
// If no native progress available
func estimateProgress() -> Double {
    let cacheURL = // MLX cache directory
    let downloadedSize = // Size of files in cache
    let expectedSize = 2_000_000_000 // ~2GB
    return min(Double(downloadedSize) / Double(expectedSize), 1.0)
}
```

### Model Storage Location

MLX likely stores models in:

- `~/Library/Caches/huggingface/hub/models--mlx-community--Qwen2.5-3B-Instruct-4bit/`
- Or similar HuggingFace cache structure

Need to:

1. Determine exact cache path
2. Check for model files to skip redundant downloads
3. Calculate size for storage warnings

### Download Interruption Handling

**Scenarios to handle:**

1. **User quits app during download**
   - MLX likely handles partial downloads internally
   - Reset `hasCompletedModelDownload` to `false` on next launch
   - Resume download from where it left off (if MLX supports)

2. **Network connection lost**
   - Catch download errors
   - Show user-friendly error message
   - Provide "Retry" button

3. **Insufficient disk space**
   - Pre-check available disk space (need ~3GB free)
   - Warn user before starting download
   - Gracefully fail with clear error message

### Model Selection Changes

When user changes model in settings:

- Compare `localModelId` with `lastDownloadedModelId`
- If different, trigger new download
- Delete old model files to save space (optional)

---

## Verification Plan

### Automated Tests

#### Unit Tests

**New test file:** `ModelDownloadServiceTests.swift`

```bash
# Run tests
swift test --filter ModelDownloadServiceTests
```

**Test cases:**

- ✅ `testIsModelDownloaded_WhenFilesExist_ReturnsTrue()`
- ✅ `testIsModelDownloaded_WhenFilesMissing_ReturnsFalse()`
- ✅ `testDownloadProgress_UpdatesCorrectly()`
- ✅ `testDownloadState_TransitionsCorrectly()`

**Note:** Actual model download tests may need to be mocked to avoid 2GB downloads in CI.

#### Integration Tests

**Test:** First launch flow simulation

```swift
func testFirstLaunchDownload() async throws {
    // Reset UserDefaults
    UserDefaults.standard.set(false, forKey: "hasCompletedModelDownload")

    let service = ModelDownloadService()

    // Verify initial state
    XCTAssertFalse(await service.isModelDownloaded(modelId: testModelId))

    // Trigger download
    try await service.downloadModel(modelId: testModelId)

    // Verify completion
    XCTAssertTrue(await service.isModelDownloaded(modelId: testModelId))
    XCTAssertEqual(UserDefaults.standard.bool(forKey: "hasCompletedModelDownload"), true)
}
```

**Run command:**

```bash
swift test --filter testFirstLaunchDownload
```

---

### Manual Verification

> [!TIP]  
> **Manual Testing Checklist**
>
> These steps require building and running the app locally. User should perform these tests to verify the feature works as expected.

#### Test 1: Fresh Install Experience

**Prerequisites:**

1. Delete MLX model cache: `rm -rf ~/Library/Caches/huggingface/hub/`
2. Reset UserDefaults: Open Terminal and run:

   ```bash
   defaults delete com.receiptsorter.app hasCompletedModelDownload
   defaults delete com.receiptsorter.app lastModelId
   ```

3. Ensure "Use Local LLM" is enabled in settings

**Steps:**

1. Launch Receipt Sorter app
2. **Expected:** Download UI appears immediately (modal/banner based on chosen option)
3. **Expected:** Progress indicator shows 0% initially
4. **Expected:** Progress advances smoothly to 100%
5. **Expected:** Download completes and UI dismisses
6. **Expected:** Can now process receipts with local LLM
7. **Expected:** Settings show "Model Status: Ready"

**Pass criteria:**

- ✅ Download starts automatically on launch
- ✅ Progress is visible and updates regularly
- ✅ Download completes successfully
- ✅ Model is ready for use after completion

---

#### Test 2: Subsequent Launch (No Re-download)

**Prerequisites:**

- Test 1 completed successfully

**Steps:**

1. Quit and relaunch Receipt Sorter app
2. **Expected:** No download UI appears
3. **Expected:** App loads normally
4. **Expected:** Can immediately process receipts
5. **Expected:** Settings show "Model Status: Ready"

**Pass criteria:**

- ✅ No download triggered on subsequent launches
- ✅ Model loads instantly from cache

---

#### Test 3: Download Interruption Recovery

**Prerequisites:**

1. Delete model cache (as in Test 1)
2. Reset UserDefaults (as in Test 1)

**Steps:**

1. Launch app to start download
2. **After ~20% progress:** Quit app (Cmd+Q)
3. Relaunch app
4. **Expected:** Download resumes from where it left off OR restarts from 0%
5. Let download complete
6. **Expected:** Model works correctly

**Pass criteria:**

- ✅ App handles interruption gracefully
- ✅ Download can complete after interruption
- ✅ Model functions correctly after interrupted download

---

#### Test 4: Network Failure Handling

**Prerequisites:**

1. Delete model cache
2. Reset UserDefaults

**Steps:**

1. Launch app to start download
2. **After ~20% progress:** Disconnect from internet (turn off WiFi)
3. **Expected:** Error message appears
4. **Expected:** UI provides "Retry" option
5. Reconnect to internet
6. Click "Retry"
7. **Expected:** Download resumes/restarts successfully

**Pass criteria:**

- ✅ Network errors are caught and displayed clearly
- ✅ User can retry without restarting app
- ✅ Download completes successfully after retry

---

#### Test 5: Model Change in Settings

**Prerequisites:**

- Test 1 completed (model downloaded)

**Steps:**

1. Open Settings
2. Change "Model Selection" to a different model ID (e.g., `mlx-community/Llama-3.2-1B-Instruct-4bit`)
3. **Expected:** App detects model change
4. **Expected:** New download triggered
5. **Expected:** Progress UI appears
6. Let download complete
7. Test receipt processing
8. **Expected:** New model is used for extraction

**Pass criteria:**

- ✅ Model change triggers new download
- ✅ New model downloads and works correctly

---

#### Test 6: Insufficient Disk Space (Optional)

**Prerequisites:**

- Requires a Mac with <3GB free space (difficult to simulate)

**Steps:**

1. Launch app on low-storage device
2. **Expected:** Warning message before download starts
3. **Expected:** User can cancel download
4. **Expected:** App still usable with Gemini API (if configured)

**Pass criteria:**

- ✅ Disk space checked before download
- ✅ Clear warning message shown
- ✅ App doesn't crash or corrupt data

---

### User Acceptance Criteria

For this feature to be considered complete:

- ✅ Model downloads automatically on first launch when Local LLM is enabled
- ✅ Download progress is clearly visible to the user
- ✅ Receipt processing is available immediately after download completes
- ✅ Subsequent app launches do not re-download the model
- ✅ Network interruptions are handled gracefully with retry options
- ✅ Changing model selection triggers appropriate re-download
- ✅ Settings accurately reflect model download status
- ✅ Users can still use Gemini API while download is in progress (if Option B/C chosen)

---

## Implementation Timeline

Estimated effort: **2-3 days**

### Day 1: Core Service Implementation

- Create `ModelDownloadService`
- Investigate MLX progress callbacks
- Implement download state management
- Add UserDefaults persistence

### Day 2: UI Integration

- Create `ModelDownloadView`
- Integrate into `ReceiptSorterApp` launch flow
- Update `ContentView` with download state handling
- Update `ModernSettingsView` with status indicators

### Day 3: Testing & Polish

- Write unit tests
- Perform manual testing
- Handle edge cases (interruptions, errors)
- Update help text and user messaging
- User acceptance testing

---

## Future Enhancements

### Phase 2: Advanced Download Features

- **Download queue**: Support downloading multiple models
- **Bandwidth throttling**: Limit download speed to not interfere with user's network
- **Scheduled downloads**: Download during off-hours
- **Delta updates**: Only download model changes, not full re-download

### Phase 3: Model Management

- **Model library**: Browse and download from curated model list
- **Model comparison**: Show accuracy/speed trade-offs
- **Automatic cleanup**: Delete unused models to save space
- **Model A/B testing**: Compare extraction quality between models

---

## Open Questions

1. **MLX Progress API**: Does MLX expose download progress? Need to investigate MLXLLM documentation.
2. **UI Option**: Which download UI option (A/B/C) does the user prefer? **Requires user feedback.**
3. **Model Size Verification**: Exact size of `Qwen2.5-3B-Instruct-4bit`? Currently assuming ~2GB.
4. **Cache Management**: Should we implement automatic cleanup of old models?
5. **Multi-model Support**: Should users be able to have multiple models downloaded simultaneously?

---

## References

- [LocalLLMService.swift](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterCore/LocalLLMService.swift) - Current implementation
- [ContentView.swift:L958](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterApp/ContentView.swift#L958) - Current "download on first use" message
- [ModernSettingsView.swift:L102-111](file:///Users/ojdavis/Claude%20Code/Receipt%20Sorter/macos/Sources/ReceiptSorterApp/ModernSettingsView.swift#L102-L111) - Model selection UI
- MLX Swift Documentation: [github.com/ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift)
- MLXLLM Documentation: [github.com/ml-explore/mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples)
