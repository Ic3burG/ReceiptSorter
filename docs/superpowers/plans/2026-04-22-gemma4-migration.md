# Gemma 4 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all AI engine paths (Gemini cloud API, Llama presets, custom model picker) with Gemma 4 as the sole, locked engine, centralizing its model ID in a single constant.

**Architecture:** Apple Vision (OCRService) continues to extract text from images and PDFs. `LocalLLMService` running Gemma 4 via MLX handles all structured data extraction from that text. A new `GemmaModel` enum holds the model ID, display name, and size estimate — one place to update for future model upgrades.

**Tech Stack:** Swift 6, SwiftUI, MLX / MLXLLM / MLXLMCommon, Apple Vision (VNRecognizeTextRequest), HuggingFace Hub SDK.

**Spec:** `docs/superpowers/specs/2026-04-22-gemma4-migration-design.md`

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| **Create** | `macos/Sources/ReceiptSorterCore/GemmaModel.swift` | Single source of truth: model ID, display name, size |
| **Delete** | `macos/Sources/ReceiptSorterCore/GeminiService.swift` | Remove cloud extractor and all its types |
| **Modify** | `macos/Sources/ReceiptSorterCore/ReceiptSorterCore.swift` | Receive `ReceiptData`, simplify init, non-optional extractor |
| **Modify** | `macos/Sources/ReceiptSorterCore/LocalLLMService.swift` | Reference `GemmaModel.modelId` constant |
| **Modify** | `macos/Sources/ReceiptSorterCore/ModelDownloadService.swift` | Reference `GemmaModel.sizeEstimateBytes` constant |
| **Modify** | `macos/Sources/ReceiptSorterApp/ContentView.swift` | Remove 3 AppStorage keys, simplify initializeCore |
| **Modify** | `macos/Sources/ReceiptSorterApp/WelcomeView.swift` | Remove apiKey/useLocalLLM bindings, show Gemma 4 |
| **Modify** | `macos/Sources/ReceiptSorterApp/ModernSettingsView.swift` | Remove model picker, toggle, Gemini key field |
| **Modify** | `macos/Sources/ReceiptSorterApp/OnboardingView.swift` | Simplify ConfigurationStep to HF token + download only |

---

## Task 1: Create GemmaModel.swift

**Files:**
- Create: `macos/Sources/ReceiptSorterCore/GemmaModel.swift`

- [ ] **Step 1: Create the file**

```swift
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

// Single source of truth for the Gemma 4 model configuration.
// To upgrade to a future model, update these three values.
public enum GemmaModel {
  public static let modelId = "mlx-community/gemma-4-e4b-it-4bit"
  public static let displayName = "Gemma 4"
  public static let sizeEstimateBytes: Int64 = 3_000_000_000
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | tail -20
```

Expected: build succeeds (new file adds no breaking changes).

- [ ] **Step 3: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add macos/Sources/ReceiptSorterCore/GemmaModel.swift && git commit -m "feat: add GemmaModel constants — single source of truth for model ID"
```

---

## Task 2: Overhaul ReceiptSorterCore.swift

Move `ReceiptData` here from `GeminiService.swift`, simplify the init to always use Gemma 4, make `dataExtractor` non-optional, and remove the `GeminiError.notConfigured` extension.

**Why `@available(macOS 14.0, *)`:** `LocalLLMService` requires macOS 14.0. Since `ReceiptSorterCore` now unconditionally creates one, it must carry the same availability annotation. The app targets macOS 14+ anyway — the old `iOS 13.0 / macOS 10.15` markers were vestigial.

**Files:**
- Modify: `macos/Sources/ReceiptSorterCore/ReceiptSorterCore.swift`

- [ ] **Step 1: Replace the entire file content**

```swift
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

import Foundation

// MARK: - Domain Model

public struct ReceiptData: Codable, Sendable, Equatable {
  public let total_amount: Double?
  public let currency: String?
  public let date: String?
  public let vendor: String?
  public let description: String?
  public let category: String?

  public init(
    total_amount: Double?, currency: String?, date: String?, vendor: String?,
    description: String?, category: String? = nil
  ) {
    self.total_amount = total_amount
    self.currency = currency
    self.date = date
    self.vendor = vendor
    self.description = description
    self.category = category
  }
}

// MARK: - Core

@available(macOS 14.0, *)
public struct ReceiptSorterCore: Sendable {
  public let ocrService: OCRService
  public let dataExtractor: ReceiptDataExtractor
  nonisolated(unsafe) public let authService: AuthService?
  public let sheetService: SheetService?
  public let excelService: ExcelService?
  public let fileOrganizationService: FileOrganizationService?

  @MainActor
  public init(
    clientID: String? = nil,
    clientSecret: String? = nil,
    sheetID: String? = nil,
    excelFilePath: String? = nil,
    organizationBasePath: String? = nil
  ) {
    self.ocrService = OCRService()
    self.dataExtractor = LocalLLMService(modelId: GemmaModel.modelId)

    if let clientID = clientID, !clientID.isEmpty {
      let auth = AuthService(clientID: clientID, clientSecret: clientSecret)
      self.authService = auth
      if let sheetID = sheetID, !sheetID.isEmpty {
        self.sheetService = SheetService(authService: auth, sheetID: sheetID)
      } else {
        self.sheetService = nil
      }
    } else {
      self.authService = nil
      self.sheetService = nil
    }

    if let excelFilePath = excelFilePath, !excelFilePath.isEmpty {
      self.excelService = ExcelService(fileURL: URL(fileURLWithPath: excelFilePath))
    } else {
      self.excelService = nil
    }

    if let organizationBasePath = organizationBasePath, !organizationBasePath.isEmpty {
      self.fileOrganizationService = FileOrganizationService(
        baseDirectory: URL(fileURLWithPath: organizationBasePath))
    } else {
      self.fileOrganizationService = nil
    }
  }

  public func extractText(from fileURL: URL) async throws -> String {
    NSLog("ReceiptSorterCore: OCR starting for file")
    let result = try await ocrService.extractText(from: fileURL)
    NSLog("ReceiptSorterCore: OCR complete, got \(result.count) chars")
    return result
  }

  public func extractReceiptData(from text: String) async throws -> ReceiptData {
    NSLog("ReceiptSorterCore: extractReceiptData called")
    NSLog("ReceiptSorterCore: About to call dataExtractor.extractData...")
    let result = try await dataExtractor.extractData(from: text)
    NSLog("ReceiptSorterCore: dataExtractor.extractData completed successfully")
    return result
  }

  // MARK: - Export Methods

  public func exportToExcel(data: ReceiptData) async throws {
    guard let excelService = excelService else {
      throw ExcelError.fileNotConfigured
    }
    try await excelService.exportReceipt(data)
  }

  public func uploadToSheets(data: ReceiptData) async throws {
    guard let sheetService = sheetService else {
      throw SheetError.sheetsNotConfigured
    }
    try await sheetService.appendReceipt(data)
  }

  public func formatSheet() async throws {
    guard let sheetService = sheetService else {
      throw SheetError.sheetsNotConfigured
    }
    try await sheetService.formatHeader()
  }

  // MARK: - File Organization

  public func organizeFile(_ fileURL: URL, date: String) async throws -> URL {
    guard let service = fileOrganizationService else {
      throw FileOrganizationError.notConfigured
    }
    return try await service.organizeReceipt(fileURL, date: date)
  }
}

public enum AuthError: LocalizedError {
  case authFailed(String)
  case notAuthorized
  case tokenRefreshFailed(String)

  public var errorDescription: String? {
    switch self {
    case .authFailed(let message):
      return "Authentication failed: \(message)"
    case .notAuthorized:
      return "Not authorized. Please sign in first."
    case .tokenRefreshFailed(let message):
      return "Token refresh failed: \(message)"
    }
  }
}
```

- [ ] **Step 2: Build — expect failure until GeminiService.swift is deleted**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | grep -E "error:|warning:" | head -20
```

Expected: errors about `ReceiptData` being redefined (it still exists in `GeminiService.swift`). That's correct — fix in the next step.

- [ ] **Step 3: Delete GeminiService.swift**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git rm macos/Sources/ReceiptSorterCore/GeminiService.swift
```

- [ ] **Step 4: Build to verify it now compiles cleanly**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | tail -20
```

Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add macos/Sources/ReceiptSorterCore/ReceiptSorterCore.swift && git commit -m "refactor: consolidate ReceiptSorterCore — remove Gemini, always use Gemma 4"
```

---

## Task 3: Update LocalLLMService.swift

Replace the hardcoded model ID string in the `init` default with `GemmaModel.modelId`.

**Files:**
- Modify: `macos/Sources/ReceiptSorterCore/LocalLLMService.swift`

- [ ] **Step 1: Change the init default**

Find this line (around line 36):
```swift
  public init(modelId: String = "mlx-community/gemma-4-e4b-it-4bit") {
```

Replace with:
```swift
  public init(modelId: String = GemmaModel.modelId) {
```

- [ ] **Step 2: Build**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | tail -10
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add macos/Sources/ReceiptSorterCore/LocalLLMService.swift && git commit -m "refactor: LocalLLMService references GemmaModel.modelId constant"
```

---

## Task 4: Update ModelDownloadService.swift

Replace the hardcoded size estimate with `GemmaModel.sizeEstimateBytes`.

**Files:**
- Modify: `macos/Sources/ReceiptSorterCore/ModelDownloadService.swift`

- [ ] **Step 1: Change the size estimate**

Find this line (around line 69):
```swift
  private let modelSizeEstimate: Int64 = 3_000_000_000  // ~2.8GB (gemma-4-e4b-it-4bit)
```

Replace with:
```swift
  private let modelSizeEstimate: Int64 = GemmaModel.sizeEstimateBytes
```

- [ ] **Step 2: Build**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | tail -10
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add macos/Sources/ReceiptSorterCore/ModelDownloadService.swift && git commit -m "refactor: ModelDownloadService references GemmaModel.sizeEstimateBytes constant"
```

---

## Task 5: Update ContentView.swift

Remove three `@AppStorage` keys (`geminiApiKey`, `useLocalLLM`, `localModelId`) and their `onChange` observers. Simplify `initializeCore()` to always create `ReceiptSorterCore` without API key or toggle. Remove the dead `useLocal`/`key` guard in `processItem`. Update the `WelcomeView` call to remove the removed bindings.

**Files:**
- Modify: `macos/Sources/ReceiptSorterApp/ContentView.swift`

- [ ] **Step 1: Remove the three AppStorage declarations**

Find and delete these three lines (around lines 56–59):
```swift
  @AppStorage("geminiApiKey") private var apiKey: String = ""
  @AppStorage("useLocalLLM") private var useLocalLLM: Bool = true
  @AppStorage("localModelId") private var localModelId: String =
    "mlx-community/Llama-3.2-3B-Instruct-4bit"
```

- [ ] **Step 2: Remove the three onChange observers**

Find and delete these three lines (around lines 126–128):
```swift
      .onChange(of: apiKey) { _, _ in initializeCore() }
      .onChange(of: useLocalLLM) { _, _ in initializeCore() }
      .onChange(of: localModelId) { _, _ in initializeCore() }
```

- [ ] **Step 3: Rewrite initializeCore()**

Find the existing `initializeCore()` method (around line 410) and replace it entirely:

Old:
```swift
  @MainActor
  private func initializeCore() {
    NSLog("ReceiptSorter: [CORE] initializeCore called, useLocalLLM=\(useLocalLLM)")

    let localService: LocalLLMService?
    if useLocalLLM {
      NSLog("ReceiptSorter: [CORE] Creating LocalLLMService...")
      localService = LocalLLMService(modelId: localModelId)
      NSLog("ReceiptSorter: [CORE] LocalLLMService created successfully")
    } else {
      localService = nil
    }

    self.core = ReceiptSorterCore(
      apiKey: apiKey,
      clientID: clientID,
      clientSecret: clientSecret,
      sheetID: googleSheetId,
      excelFilePath: excelFilePath,
      organizationBasePath: organizationBasePath,
      localLLMService: localService
    )
    NSLog("ReceiptSorter: [CORE] ReceiptSorterCore initialized")

    Task {
      if let auth = core?.authService {
        self.isAuthorized = auth.isAuthorized
      }
    }
  }
```

New:
```swift
  @MainActor
  private func initializeCore() {
    NSLog("ReceiptSorter: [CORE] initializeCore called")
    self.core = ReceiptSorterCore(
      clientID: clientID,
      clientSecret: clientSecret,
      sheetID: googleSheetId,
      excelFilePath: excelFilePath,
      organizationBasePath: organizationBasePath
    )
    NSLog("ReceiptSorter: [CORE] ReceiptSorterCore initialized")

    Task {
      if let auth = core?.authService {
        self.isAuthorized = auth.isAuthorized
      }
    }
  }
```

- [ ] **Step 4: Remove the dead guard in processItem**

Find this block in `processItem(at:)` (around line 525):
```swift
      let (item, useLocal, key) = await MainActor.run {
        (items[index], useLocalLLM, apiKey)
      }
```

Replace with:
```swift
      let item = await MainActor.run { items[index] }
```

Then find and delete the guard that references those now-removed variables (a few lines below):
```swift
      if !useLocal && key.isEmpty {
        await MainActor.run { items[index].error = "Missing API Key" }
        return
      }
```

- [ ] **Step 5: Update the WelcomeView call in sidebarContent**

Find the `WelcomeView` call (around line 180):
```swift
        WelcomeView(
          apiKey: $apiKey,
          useLocalLLM: $useLocalLLM,
          excelFilePath: $excelFilePath,
          organizationBasePath: $organizationBasePath,
          isAuthorized: isAuthorized,
          onSignIn: signIn
        )
```

Replace with:
```swift
        WelcomeView(
          excelFilePath: $excelFilePath,
          organizationBasePath: $organizationBasePath,
          isAuthorized: isAuthorized,
          onSignIn: signIn
        )
```

- [ ] **Step 6: Build — will error until WelcomeView.swift is updated**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | grep "error:" | head -10
```

Expected: errors about `WelcomeView` init mismatch and missing `apiKey`/`useLocalLLM`. Fix in Task 6.

---

## Task 6: Update WelcomeView.swift

Remove `apiKey` and `useLocalLLM` bindings. Simplify the setup-progress row to always show "Local AI · Gemma 4" as configured (download status is shown in the `ModelDownloadBanner` which wraps the whole screen).

**Files:**
- Modify: `macos/Sources/ReceiptSorterApp/WelcomeView.swift`

- [ ] **Step 1: Remove the two binding declarations**

Find and delete these two lines (near the top of `WelcomeView`):
```swift
  @Binding var apiKey: String
  @Binding var useLocalLLM: Bool
```

- [ ] **Step 2: Update isFullyConfigured**

Find:
```swift
  private var isFullyConfigured: Bool {
    (!apiKey.isEmpty || useLocalLLM) && !excelFilePath.isEmpty && !organizationBasePath.isEmpty
  }
```

Replace with:
```swift
  private var isFullyConfigured: Bool {
    !excelFilePath.isEmpty && !organizationBasePath.isEmpty
  }
```

- [ ] **Step 3: Update configuredCount**

Find:
```swift
  private var configuredCount: Int {
    var count = 0
    if !apiKey.isEmpty || useLocalLLM { count += 1 }
    if !excelFilePath.isEmpty { count += 1 }
    if !organizationBasePath.isEmpty { count += 1 }
    return count
  }
```

Replace with:
```swift
  private var configuredCount: Int {
    var count = 1  // AI is always configured (Gemma 4 local)
    if !excelFilePath.isEmpty { count += 1 }
    if !organizationBasePath.isEmpty { count += 1 }
    return count
  }
```

- [ ] **Step 4: Update the AI setup row**

Find:
```swift
              setupItem(
                icon: useLocalLLM ? "cpu" : "key",
                title: useLocalLLM ? "Local AI" : "Gemini API",
                isConfigured: useLocalLLM || !apiKey.isEmpty
              )
```

Replace with:
```swift
              setupItem(
                icon: "cpu",
                title: "Local AI · \(GemmaModel.displayName)",
                isConfigured: true
              )
```

- [ ] **Step 5: Add import for ReceiptSorterCore if not already present**

Check the imports at the top of `WelcomeView.swift`. It already has `import ReceiptSorterCore`, so `GemmaModel` is available.

- [ ] **Step 6: Build**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | tail -15
```

Expected: build succeeds.

- [ ] **Step 7: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add macos/Sources/ReceiptSorterApp/ContentView.swift macos/Sources/ReceiptSorterApp/WelcomeView.swift && git commit -m "refactor: remove Gemini/toggle AppStorage from ContentView and WelcomeView"
```

---

## Task 7: Update ModernSettingsView.swift

Remove the `ModelOption` enum, model picker, custom model ID field, `useLocalLLM` toggle, and Gemini API key field from `GeneralSettingsDetailView`. Replace with an informational Gemma 4 label and keep the Hugging Face token field.

**Files:**
- Modify: `macos/Sources/ReceiptSorterApp/ModernSettingsView.swift`

- [ ] **Step 1: Replace GeneralSettingsDetailView entirely**

Find the `struct GeneralSettingsDetailView: View {` block (starting around line 96) and replace the entire struct with:

```swift
struct GeneralSettingsDetailView: View {
  @AppStorage("hfToken") private var hfToken: String = ""
  @EnvironmentObject var modelDownloadService: ModelDownloadService

  var body: some View {
    Form {
      Section {
        LabeledContent("Model") {
          VStack(alignment: .leading, spacing: 4) {
            Text(GemmaModel.displayName)
              .fontWeight(.medium)
            Text("~\(GemmaModel.sizeEstimateBytes / 1_000_000_000)GB · Runs entirely on your device")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        // Download status
        if case .downloading(let progress) = modelDownloadService.state {
          LabeledContent("Download Progress") {
            HStack {
              ProgressView(value: progress)
              Text("\(Int(progress * 100))%")
                .font(.caption)
                .monospacedDigit()
            }
          }
        } else if modelDownloadService.isModelDownloaded(modelId: GemmaModel.modelId) {
          LabeledContent("Status") {
            Label("Ready", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .font(.caption)
          }
        } else {
          LabeledContent("Status") {
            Label("Not downloaded", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
              .font(.caption)
          }
        }
      } header: {
        Text("Artificial Intelligence")
      } footer: {
        Text("Processing happens entirely on your device using MLX. No data leaves your Mac.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        LabeledContent {
          VStack(alignment: .leading) {
            SecureField("Enter your token", text: $hfToken)
              .textFieldStyle(.roundedBorder)
              .textContentType(.password)
              .onChange(of: hfToken) { _, newValue in
                if !newValue.isEmpty {
                  setenv("HF_TOKEN", newValue, 1)
                }
              }

            if !hfToken.isEmpty {
              Text("Token configured")
                .font(.caption)
                .foregroundStyle(.green)
            }
          }
        } label: {
          Text("Hugging Face Token")
        }
      } header: {
        Text("Authentication")
      } footer: {
        VStack(alignment: .leading, spacing: 4) {
          Text("Required for model downloads.")
          Link(
            "Get a free token from Hugging Face",
            destination: URL(string: "https://huggingface.co/settings/tokens")!
          )
          .font(.caption)
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("General")
  }
}
```

- [ ] **Step 2: Build**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | tail -15
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add macos/Sources/ReceiptSorterApp/ModernSettingsView.swift && git commit -m "refactor: simplify Settings — lock to Gemma 4, remove model picker and Gemini key"
```

---

## Task 8: Update OnboardingView.swift

Simplify `ConfigurationStep` to remove the cloud toggle and Gemini API key field. It becomes a single informational view explaining local-only processing.

**Files:**
- Modify: `macos/Sources/ReceiptSorterApp/OnboardingView.swift`

- [ ] **Step 1: Update the ConfigurationStep call site**

Find (around line 91):
```swift
            ConfigurationStep(apiKey: $apiKey, useLocalLLM: $useLocalLLM).transition(.opacity)
```

Replace with:
```swift
            ConfigurationStep().transition(.opacity)
```

- [ ] **Step 2: Replace the ConfigurationStep struct**

Find the `struct ConfigurationStep: View {` block and replace it entirely:

Old:
```swift
struct ConfigurationStep: View {
  @Binding var apiKey: String
  @Binding var useLocalLLM: Bool

  var body: some View {
    VStack(spacing: 32) {
      Text("Configuration")
        .font(.title)

      VStack(spacing: 24) {
        GroupBox {
          Toggle("Use Local Intelligence", isOn: $useLocalLLM)
            .toggleStyle(.switch)
            .font(.headline)
        }

        if !useLocalLLM {
          VStack(alignment: .leading, spacing: 8) {
            Text("Gemini API Key")
              .font(.headline)

            HStack {
              Image(systemName: "key.fill")
                .foregroundColor(.secondary)
              SecureField("Enter API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .privacySensitive()
            }

            Link("Get API Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
              .font(.caption)
          }
          .transition(.opacity)
        } else {
          Text("Local models run directly on your Mac. No data leaves your device.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
      }
      .padding(.horizontal, 40)
    }
  }
}
```

New:
```swift
struct ConfigurationStep: View {
  @AppStorage("hfToken") private var hfToken: String = ""
  @EnvironmentObject var modelDownloadService: ModelDownloadService

  var body: some View {
    VStack(spacing: 32) {
      Text("Configuration")
        .font(.title)

      VStack(spacing: 24) {
        GroupBox {
          VStack(alignment: .leading, spacing: 12) {
            Label("Local AI · \(GemmaModel.displayName)", systemImage: "cpu")
              .font(.headline)

            Text("Receipt Sorter runs entirely on your Mac using MLX. No data leaves your device.")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)
        }

        GroupBox {
          VStack(alignment: .leading, spacing: 8) {
            Text("Hugging Face Token")
              .font(.headline)

            SecureField("Enter token (required for download)", text: $hfToken)
              .textFieldStyle(.roundedBorder)
              .textContentType(.password)
              .onChange(of: hfToken) { _, newValue in
                if !newValue.isEmpty {
                  setenv("HF_TOKEN", newValue, 1)
                }
              }

            Link(
              "Get a free token from Hugging Face",
              destination: URL(string: "https://huggingface.co/settings/tokens")!
            )
            .font(.caption)
          }
          .padding(.vertical, 4)
        }

        if case .downloading(let progress) = modelDownloadService.state {
          ProgressView(value: progress) {
            Text("Downloading \(GemmaModel.displayName)…")
              .font(.caption)
          }
        } else if modelDownloadService.isModelDownloaded(modelId: GemmaModel.modelId) {
          Label("\(GemmaModel.displayName) ready", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.caption)
        }
      }
      .padding(.horizontal, 40)
    }
  }
}
```

- [ ] **Step 3: Remove the `@AppStorage("geminiApiKey")` and `@AppStorage("useLocalLLM")` declarations from OnboardingView**

Find and delete these lines near the top of `OnboardingView` (around lines 33–34):
```swift
  @AppStorage("geminiApiKey") private var apiKey: String = ""
  @AppStorage("useLocalLLM") private var useLocalLLM: Bool = true
```

- [ ] **Step 4: Build**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build 2>&1 | tail -15
```

Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add macos/Sources/ReceiptSorterApp/OnboardingView.swift && git commit -m "refactor: simplify Onboarding — remove cloud toggle, Gemini key step"
```

---

## Task 9: Final Build and Smoke Test

- [ ] **Step 1: Clean build**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter/macos" && swift build -c release 2>&1 | tail -20
```

Expected: `Build complete!` with no errors.

- [ ] **Step 2: Grep for any remaining references to removed symbols**

```bash
grep -rn "geminiApiKey\|useLocalLLM\|localModelId\|GeminiService\|GeminiError\|gemini-2.0-flash\|Llama-3.2" \
  "/Users/ojdavis/Claude Code/Receipt Sorter/macos/Sources" 2>/dev/null
```

Expected: no output. If any lines appear, fix them before proceeding.

- [ ] **Step 3: Smoke test in Xcode**

Open the project in Xcode (`open /Users/ojdavis/Claude\ Code/Receipt\ Sorter/macos/.swiftpm/xcode/package.xcworkspace`), run the app, and verify:

1. Settings (⌘,) → General shows "Gemma 4 · ~3GB · Runs entirely on your device" with no model picker and no Gemini key field.
2. Onboarding (reset via `UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")` in the Xcode console) shows the simplified ConfigurationStep with HF token only.
3. Drop an image receipt — OCR runs, Gemma 4 extracts structured data, result appears.
4. No crash logs mentioning `GeminiService`, `GeminiError`, or missing API key.

- [ ] **Step 4: Final commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter" && git add -A && git status
```

Confirm there are no unexpected staged files, then commit if anything remains:

```bash
git commit -m "chore: Gemma 4 migration complete — all other model paths removed"
```
