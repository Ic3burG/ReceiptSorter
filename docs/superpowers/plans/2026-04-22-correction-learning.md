# Correction & Learning System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users correct extracted receipt fields inline and have the app learn from those corrections via few-shot prompt injection and deterministic rule application.

**Architecture:** A `CorrectionStore` (JSON file in Application Support) records user edits, auto-promotes repeated corrections to Rules at count ≥ 3, injects the 5 most recent corrections as few-shot examples into the LLM system prompt, and applies Rules deterministically after every extraction. The UI gains click-to-edit `EditableDataCard` components and a Corrections section in Settings.

**Tech Stack:** Swift 6, SwiftUI, `@MainActor ObservableObject` (`CorrectionStore`), Swift `actor` (`LocalLLMService`), `Foundation.JSONEncoder/Decoder` for persistence.

**Spec:** `docs/superpowers/specs/2026-04-22-correction-learning-design.md`

---

### Task 1: CorrectionStore — data model and persistence

**Files:**
- Create: `macos/Sources/ReceiptSorterCore/CorrectionStore.swift`

- [ ] **Step 1: Create `CorrectionStore.swift` with the data model and persistence**

```swift
// macos/Sources/ReceiptSorterCore/CorrectionStore.swift

/*
 * ReceiptSorter
 * Copyright (c) 2025 OJD Technical Solutions
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import Foundation

public struct Correction: Codable, Identifiable, Sendable {
  public let id: UUID
  public let field: String      // "vendor" | "currency" | "category" | "date" | "description"
  public let original: String
  public let corrected: String
  public var count: Int
  public let createdAt: Date
  public var updatedAt: Date
}

public struct Rule: Codable, Identifiable, Sendable {
  public let id: UUID
  public let field: String
  public let original: String
  public let corrected: String
  public var applyCount: Int
  public let promotedAt: Date
}

private struct StoreDocument: Codable {
  var corrections: [Correction]
  var rules: [Rule]
}

@available(macOS 14.0, *)
@MainActor
public class CorrectionStore: ObservableObject {
  @Published public private(set) var corrections: [Correction] = []
  @Published public private(set) var rules: [Rule] = []

  private let storeURL: URL

  public init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("ReceiptSorter", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    storeURL = dir.appendingPathComponent("corrections.json")
    load()
  }

  // MARK: - Persistence

  private func load() {
    guard
      let data = try? Data(contentsOf: storeURL),
      let doc = try? JSONDecoder().decode(StoreDocument.self, from: data)
    else { return }
    corrections = doc.corrections
    rules = doc.rules
  }

  func save() {
    let doc = StoreDocument(corrections: corrections, rules: rules)
    guard let data = try? JSONEncoder().encode(doc) else {
      NSLog("ReceiptSorter: [CorrectionStore] Failed to encode corrections")
      return
    }
    try? data.write(to: storeURL, options: .atomic)
  }
}
```

- [ ] **Step 2: Build to verify the file compiles**

In Xcode press **⌘B**. Expected: Build Succeeded with no errors.

- [ ] **Step 3: Commit**

```bash
cd "/Users/ojdavis/Claude Code/Receipt Sorter"
git add macos/Sources/ReceiptSorterCore/CorrectionStore.swift
git commit -m "feat: add CorrectionStore data model and persistence"
```

---

### Task 2: CorrectionStore — business logic

**Files:**
- Modify: `macos/Sources/ReceiptSorterCore/CorrectionStore.swift` (add methods)

- [ ] **Step 1: Add business logic methods to `CorrectionStore`**

Add the following extension at the bottom of `CorrectionStore.swift`, after the closing `}` of the class:

```swift
// MARK: - Business Logic

@available(macOS 14.0, *)
extension CorrectionStore {

  /// Records a user correction. Creates a new Correction or increments an existing one.
  /// Auto-promotes to a Rule when count reaches 3.
  public func record(field: String, original: String, corrected: String) {
    let trimmedOriginal = original.trimmingCharacters(in: .whitespaces)
    let trimmedCorrected = corrected.trimmingCharacters(in: .whitespaces)
    guard trimmedOriginal != trimmedCorrected,
      !trimmedOriginal.isEmpty,
      !trimmedCorrected.isEmpty
    else { return }

    if let idx = corrections.firstIndex(where: {
      $0.field == field
        && $0.original.lowercased() == trimmedOriginal.lowercased()
        && $0.corrected == trimmedCorrected
    }) {
      corrections[idx].count += 1
      corrections[idx].updatedAt = Date()
      let count = corrections[idx].count
      let alreadyHasRule = rules.contains {
        $0.field == field && $0.original.lowercased() == trimmedOriginal.lowercased()
      }
      if count >= 3 && !alreadyHasRule {
        rules.append(
          Rule(
            id: UUID(), field: field, original: trimmedOriginal,
            corrected: trimmedCorrected, applyCount: 0, promotedAt: Date()))
      }
    } else {
      corrections.append(
        Correction(
          id: UUID(), field: field, original: trimmedOriginal, corrected: trimmedCorrected,
          count: 1, createdAt: Date(), updatedAt: Date()))
    }
    save()
  }

  /// Returns a prompt snippet of the 5 most recent corrections, or nil if none exist.
  public func buildFewShotSnippet() -> String? {
    guard !corrections.isEmpty else { return nil }
    let lines = corrections
      .sorted { $0.updatedAt > $1.updatedAt }
      .prefix(5)
      .map { "- \($0.field): \"\($0.original)\" → \"\($0.corrected)\"" }
    return "Past corrections (apply these patterns to new receipts):\n" + lines.joined(separator: "\n")
  }

  /// Applies all Rules to an extracted ReceiptData. Returns the corrected data.
  /// Increments applyCount on each matched rule.
  public func applyRules(to data: ReceiptData) -> ReceiptData {
    guard !rules.isEmpty else { return data }

    func corrected(field: String, value: String?) -> String? {
      guard let value else { return nil }
      guard let idx = rules.firstIndex(where: {
        $0.field == field && $0.original.lowercased() == value.lowercased()
      }) else { return value }
      rules[idx].applyCount += 1
      return rules[idx].corrected
    }

    let result = ReceiptData(
      total_amount: data.total_amount,
      currency: corrected(field: "currency", value: data.currency),
      date: corrected(field: "date", value: data.date),
      vendor: corrected(field: "vendor", value: data.vendor),
      description: corrected(field: "description", value: data.description),
      category: corrected(field: "category", value: data.category)
    )
    save()
    return result
  }

  // MARK: - Management

  public func deleteCorrection(id: UUID) {
    corrections.removeAll { $0.id == id }
    save()
  }

  public func deleteRule(id: UUID) {
    rules.removeAll { $0.id == id }
    save()
  }

  public func clearAll() {
    corrections.removeAll()
    rules.removeAll()
    save()
  }
}
```

- [ ] **Step 2: Build to verify**

Press **⌘B**. Expected: Build Succeeded.

- [ ] **Step 3: Manually verify logic (mental walkthrough)**

Trace through `record(field: "vendor", original: "Mcdonalds", corrected: "McDonald's")` called 3 times:
- Call 1: corrections = [Correction(count: 1)], rules = []
- Call 2: corrections = [Correction(count: 2)], rules = []
- Call 3: corrections = [Correction(count: 3)], rules = [Rule(applyCount: 0)]

Trace `applyRules` with a Rule `{field: "vendor", original: "Mcdonalds", corrected: "McDonald's"}` and input `ReceiptData(vendor: "mcdonalds")`:
- `"mcdonalds".lowercased() == "mcdonalds".lowercased()` → match
- Output: `ReceiptData(vendor: "McDonald's")`

- [ ] **Step 4: Commit**

```bash
git add macos/Sources/ReceiptSorterCore/CorrectionStore.swift
git commit -m "feat: add CorrectionStore business logic (record, few-shot, rules)"
```

---

### Task 3: Wire CorrectionStore into the app, ReceiptSorterCore, and LocalLLMService

**Files:**
- Modify: `macos/Sources/ReceiptSorterApp/ReceiptSorterApp.swift`
- Modify: `macos/Sources/ReceiptSorterCore/ReceiptSorterCore.swift`
- Modify: `macos/Sources/ReceiptSorterCore/LocalLLMService.swift`

- [ ] **Step 1: Lift `CorrectionStore` to app level in `ReceiptSorterApp.swift`**

Add `@StateObject private var correctionStore = CorrectionStore()` alongside the existing `modelDownloadService` property, then pass it as an environment object to both the main window and Settings scene.

Replace the entire `ReceiptSorterApp.swift` body content (keeping the license header):

```swift
@main
struct ReceiptSorterApp: App {
  @StateObject private var modelDownloadService = ModelDownloadService()
  @StateObject private var correctionStore = CorrectionStore()
  @AppStorage("hasCompletedModelDownload") private var hasCompletedDownload = false
  @AppStorage("hfToken") private var hfToken: String = ""

  init() {
    if let token = UserDefaults.standard.string(forKey: "hfToken"), !token.isEmpty {
      setenv("HF_TOKEN", token, 1)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(modelDownloadService)
        .environmentObject(correctionStore)
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
        .environmentObject(correctionStore)
    }
  }

  private func checkAndDownloadModel() async {
    guard !modelDownloadService.isModelDownloaded(modelId: GemmaModel.modelId) else { return }
    guard !hfToken.isEmpty else { return }
    modelDownloadService.downloadModel(modelId: GemmaModel.modelId)
  }
}
```

- [ ] **Step 2: Add `correctionStore` to `ReceiptSorterCore`**

In `ReceiptSorterCore.swift`, update the struct and `init`:

```swift
public struct ReceiptSorterCore: Sendable {
  public let ocrService: OCRService
  public let dataExtractor: ReceiptDataExtractor
  nonisolated(unsafe) public let authService: AuthService?
  public let sheetService: SheetService?
  public let excelService: ExcelService?
  public let fileOrganizationService: FileOrganizationService?
  public let correctionStore: CorrectionStore

  @MainActor
  public init(
    correctionStore: CorrectionStore = CorrectionStore(),
    clientID: String? = nil,
    clientSecret: String? = nil,
    sheetID: String? = nil,
    excelFilePath: String? = nil,
    organizationBasePath: String? = nil
  ) {
    self.correctionStore = correctionStore
    self.ocrService = OCRService()
    self.dataExtractor = LocalLLMService(
      modelId: GemmaModel.modelId, correctionStore: correctionStore)

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
  // ... rest of struct unchanged
}
```

- [ ] **Step 3: Update `LocalLLMService` to accept and use `CorrectionStore`**

In `LocalLLMService.swift`, make the following changes:

**3a.** Add `correctionStore` property and update `init` (replace the existing `init`):

```swift
private let modelId: String
private var modelContainer: ModelContainer?
nonisolated(unsafe) private let correctionStore: CorrectionStore

public init(modelId: String = GemmaModel.modelId, correctionStore: CorrectionStore) {
  self.modelId = modelId
  self.correctionStore = correctionStore
  NSLog("ReceiptSorter: [LLM] LocalLLMService initialized with model: \(modelId)")
}
```

**3b.** In `extractData(from:)`, fetch the few-shot snippet before building the prompt. Replace the `let systemPrompt = """` block with:

```swift
// Fetch few-shot corrections from the store (MainActor call from actor context)
let fewShotSnippet = await MainActor.run { correctionStore.buildFewShotSnippet() }
let correctionPrefix = fewShotSnippet.map { $0 + "\n\n" } ?? ""

let systemPrompt = """
  \(correctionPrefix)You are a receipt scanner AI. Extract data from the receipt below into JSON.

  JSON Schema:
  {
    "vendor": "string",
    "date": "YYYY-MM-DD",
    "total_amount": number,
    "currency": "CAD",
    "category": "string",
    "description": "string"
  }

  Categories: Groceries, Dining, Gas, Transport, Shopping, Other

  Instructions:
  - Output ONLY valid JSON.
  - "category" must be one of the Categories list.
  - If currency is unknown, use "CAD".
  - Do not use markdown.
  """
```

**3c.** After `return try parseResponse(fullOutput)` in the do-block, apply rules before returning. Replace:

```swift
return try parseResponse(fullOutput)
```

with:

```swift
let parsed = try parseResponse(fullOutput)
let corrected = await MainActor.run { correctionStore.applyRules(to: parsed) }
return corrected
```

- [ ] **Step 4: Update `ContentView` to receive `correctionStore` from environment and pass it to `ReceiptSorterCore`**

In `ContentView.swift`:

**4a.** Add environment object property alongside `modelDownloadService`:
```swift
@EnvironmentObject var correctionStore: CorrectionStore
```

**4b.** In `initializeCore()`, pass `correctionStore` as the first argument:
```swift
@MainActor
private func initializeCore() {
  NSLog("ReceiptSorter: [CORE] initializeCore called")
  self.core = ReceiptSorterCore(
    correctionStore: correctionStore,
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

- [ ] **Step 5: Build to verify**

Press **⌘B**. Expected: Build Succeeded.

- [ ] **Step 6: Commit**

```bash
git add macos/Sources/ReceiptSorterApp/ReceiptSorterApp.swift \
        macos/Sources/ReceiptSorterCore/ReceiptSorterCore.swift \
        macos/Sources/ReceiptSorterCore/LocalLLMService.swift \
        macos/Sources/ReceiptSorterApp/ContentView.swift
git commit -m "feat: wire CorrectionStore through app, core, and LLM service"
```

---

### Task 4: EditableDataCard component

**Files:**
- Create: `macos/Sources/ReceiptSorterApp/EditableDataCard.swift`

- [ ] **Step 1: Create `EditableDataCard.swift`**

```swift
// macos/Sources/ReceiptSorterApp/EditableDataCard.swift

/*
 * ReceiptSorter
 * Copyright (c) 2025 OJD Technical Solutions
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import SwiftUI

/// A receipt data field card that switches to an inline TextField on tap.
/// Calls `onCommit(original, corrected)` when the user confirms an edit.
/// A small orange dot appears on the title when `isCorrected` is true.
struct EditableDataCard: View {
  let title: String
  let icon: String
  let value: String?
  let isCorrected: Bool
  /// Called with (originalValue, newValue) only when they differ and newValue is non-empty.
  let onCommit: (String, String) -> Void

  @State private var isEditing = false
  @State private var editText = ""
  @State private var isHovering = false
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      ZStack {
        Circle()
          .fill(.ultraThinMaterial)
          .frame(width: 36, height: 36)
        Image(systemName: icon)
          .foregroundColor(.secondary)
          .font(.system(size: 14))
      }

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
          if isCorrected {
            Circle()
              .fill(Color.orange)
              .frame(width: 5, height: 5)
          }
        }

        if isEditing {
          TextField("", text: $editText)
            .font(.body)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { commit() }
            .onChange(of: isFocused) { _, focused in
              if !focused { commit() }
            }
        } else {
          Text(value ?? "Unknown")
            .font(.body)
            .foregroundColor(.primary)
            .contentShape(Rectangle())
            .onTapGesture { startEditing() }
        }
      }

      Spacer()

      if isHovering && !isEditing {
        Image(systemName: "pencil")
          .foregroundColor(.secondary)
          .font(.caption)
          .transition(.opacity)
      }
    }
    .padding(12)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(
          isEditing
            ? Color.accentColor.opacity(0.05)
            : .ultraThinMaterial.opacity(0.3)
        )
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          isEditing
            ? AnyShapeStyle(Color.accentColor.opacity(0.4))
            : AnyShapeStyle(
              LinearGradient(
                colors: [.white.opacity(0.1), .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            ),
          lineWidth: isEditing ? 1 : 0.5
        )
    }
    .animation(.easeInOut(duration: 0.15), value: isEditing)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
    }
  }

  private func startEditing() {
    editText = value ?? ""
    isEditing = true
    isFocused = true
  }

  private func commit() {
    isEditing = false
    let original = value ?? ""
    let trimmed = editText.trimmingCharacters(in: .whitespaces)
    guard trimmed != original, !trimmed.isEmpty else { return }
    onCommit(original, trimmed)
  }
}
```

- [ ] **Step 2: Build to verify**

Press **⌘B**. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add macos/Sources/ReceiptSorterApp/EditableDataCard.swift
git commit -m "feat: add EditableDataCard click-to-edit component"
```

---

### Task 5: Wire EditableDataCard into ContentView

**Files:**
- Modify: `macos/Sources/ReceiptSorterApp/ContentView.swift`

- [ ] **Step 1: Add `correctedFields` tracking to `ProcessingItem`**

In `ContentView.swift`, update `ProcessingItem` to track which fields were corrected this session. Add the property after `var organized: Bool = false`:

```swift
struct ProcessingItem: Identifiable, Equatable {
  let id = UUID()
  var url: URL
  var status: ItemStatus = .pending
  var data: ReceiptData?
  var error: String?
  var organized: Bool = false
  var correctedFields: Set<String> = []

  enum ItemStatus: Equatable {
    case pending
    case processing
    case extracted
    case syncing
    case done
    case error
  }
}
```

- [ ] **Step 2: Add `applyCorrection` helper to `ContentView`**

Add this private method in the `// MARK: - Logic` section of `ContentView`:

```swift
@MainActor
private func applyCorrection(at index: Int, field: String, original: String, corrected: String) {
  correctionStore.record(field: field, original: original, corrected: corrected)
  items[index].correctedFields.insert(field)

  guard let data = items[index].data else { return }
  let d = data
  let updated: ReceiptData
  switch field {
  case "vendor":
    updated = ReceiptData(
      total_amount: d.total_amount, currency: d.currency, date: d.date,
      vendor: corrected, description: d.description, category: d.category)
  case "currency":
    updated = ReceiptData(
      total_amount: d.total_amount, currency: corrected, date: d.date,
      vendor: d.vendor, description: d.description, category: d.category)
  case "date":
    updated = ReceiptData(
      total_amount: d.total_amount, currency: d.currency, date: corrected,
      vendor: d.vendor, description: d.description, category: d.category)
  case "description":
    updated = ReceiptData(
      total_amount: d.total_amount, currency: d.currency, date: d.date,
      vendor: d.vendor, description: corrected, category: d.category)
  case "category":
    updated = ReceiptData(
      total_amount: d.total_amount, currency: d.currency, date: d.date,
      vendor: d.vendor, description: d.description, category: corrected)
  default:
    return
  }
  items[index].data = updated
}
```

- [ ] **Step 3: Replace `DataCard` calls with `EditableDataCard` in the detail pane**

Find the block in `detailContent` that renders `DataCard` views (around line 332–340). Replace the entire block of five `DataCard` calls with `EditableDataCard` calls. The `index` variable is already in scope from `let index = items.firstIndex(...)`.

```swift
if let data = item.data {
  EditableDataCard(
    title: "Vendor", icon: "building.2",
    value: data.vendor,
    isCorrected: item.correctedFields.contains("vendor")
  ) { original, corrected in
    applyCorrection(at: index, field: "vendor", original: original, corrected: corrected)
  }

  EditableDataCard(
    title: "Date", icon: "calendar",
    value: data.date,
    isCorrected: item.correctedFields.contains("date")
  ) { original, corrected in
    applyCorrection(at: index, field: "date", original: original, corrected: corrected)
  }

  EditableDataCard(
    title: "Amount", icon: "dollarsign.circle",
    value: String(format: "%.2f", data.total_amount ?? 0.0),
    isCorrected: item.correctedFields.contains("total_amount")
  ) { _, corrected in
    // Amount edits update the value but don't feed into the correction store
    // (numeric field — model extracts numbers reliably; rules cover string fields only)
    if let amount = Double(corrected) {
      let d = data
      items[index].data = ReceiptData(
        total_amount: amount, currency: d.currency, date: d.date,
        vendor: d.vendor, description: d.description, category: d.category)
      items[index].correctedFields.insert("total_amount")
    }
  }

  EditableDataCard(
    title: "Currency", icon: "coloncurrencysign.circle",
    value: data.currency,
    isCorrected: item.correctedFields.contains("currency")
  ) { original, corrected in
    applyCorrection(at: index, field: "currency", original: original, corrected: corrected)
  }

  EditableDataCard(
    title: "Category", icon: "tag",
    value: data.category,
    isCorrected: item.correctedFields.contains("category")
  ) { original, corrected in
    applyCorrection(at: index, field: "category", original: original, corrected: corrected)
  }

  EditableDataCard(
    title: "Description", icon: "text.alignleft",
    value: data.description,
    isCorrected: item.correctedFields.contains("description")
  ) { original, corrected in
    applyCorrection(at: index, field: "description", original: original, corrected: corrected)
  }

  // ... existing done/error/processing states follow unchanged
}
```

Also delete the `DataCard` struct at the bottom of `ContentView.swift` (lines starting `/// A card displaying extracted receipt data` through the closing `}`). `EditableDataCard` replaces it entirely.

- [ ] **Step 4: Build to verify**

Press **⌘B**. Expected: Build Succeeded.

- [ ] **Step 5: Run the app and manually test editing**

Press **⌘R**. Drop a receipt image or PDF. After extraction:
- Hover over a field — pencil icon should appear on the right
- Click the vendor value — TextField appears pre-filled
- Type a correction, press Return — field updates, orange dot appears on the title
- Click away from another field mid-edit — edit should commit

- [ ] **Step 6: Commit**

```bash
git add macos/Sources/ReceiptSorterApp/ContentView.swift
git commit -m "feat: replace DataCard with EditableDataCard, record corrections"
```

---

### Task 6: Corrections section in Settings

**Files:**
- Modify: `macos/Sources/ReceiptSorterApp/ModernSettingsView.swift`

- [ ] **Step 1: Add `.corrections` to `SettingsSection`**

In `ModernSettingsView.swift`, update the `SettingsSection` enum:

```swift
enum SettingsSection: String, CaseIterable, Identifiable {
  case general = "General"
  case export = "Export"
  case organization = "Organization"
  case corrections = "Corrections"
  case cloudSync = "Cloud Sync"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .general: return "gear"
    case .export: return "square.and.arrow.up"
    case .organization: return "folder"
    case .corrections: return "brain"
    case .cloudSync: return "icloud"
    }
  }

  var color: Color {
    switch self {
    case .general: return .gray
    case .export: return .blue
    case .organization: return .cyan
    case .corrections: return .purple
    case .cloudSync: return .blue
    }
  }
}
```

- [ ] **Step 2: Add `.corrections` case to `settingsDetailView`**

In `settingsDetailView(for:)`, add the new case:

```swift
case .corrections:
  CorrectionsSettingsDetailView()
```

- [ ] **Step 3: Add `CorrectionsSettingsDetailView` to `ModernSettingsView.swift`**

Append this struct after `CloudSyncSettingsDetailView`:

```swift
// MARK: - Corrections Settings Detail View

struct CorrectionsSettingsDetailView: View {
  @EnvironmentObject var correctionStore: CorrectionStore
  @State private var showClearConfirmation = false

  var body: some View {
    Form {
      if !correctionStore.rules.isEmpty {
        Section {
          ForEach(correctionStore.rules.sorted { $0.applyCount > $1.applyCount }) { rule in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 2) {
                Text(rule.field.capitalized)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("\"\(rule.original)\" → \"\(rule.corrected)\"")
                  .font(.body)
              }
              Spacer()
              Text("applied \(rule.applyCount)×")
                .font(.caption)
                .foregroundStyle(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())
              Button(role: .destructive) {
                correctionStore.deleteRule(id: rule.id)
              } label: {
                Image(systemName: "trash")
                  .foregroundStyle(.red)
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
          }
        } header: {
          Text("Rules (applied automatically)")
        } footer: {
          Text("Promoted from corrections seen 3 or more times. Applied to every extraction.")
            .font(.caption)
        }
      }

      if !correctionStore.corrections.isEmpty {
        Section {
          ForEach(correctionStore.corrections.sorted { $0.updatedAt > $1.updatedAt }) { c in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 2) {
                Text(c.field.capitalized)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("\"\(c.original)\" → \"\(c.corrected)\"")
                  .font(.body)
              }
              Spacer()
              if c.count > 1 {
                Text("×\(c.count)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Button(role: .destructive) {
                correctionStore.deleteCorrection(id: c.id)
              } label: {
                Image(systemName: "trash")
                  .foregroundStyle(.red)
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
          }
        } header: {
          Text("Examples (injected into AI prompt)")
        } footer: {
          Text("The 5 most recent examples are shown to the AI before each extraction.")
            .font(.caption)
        }
      }

      if correctionStore.corrections.isEmpty && correctionStore.rules.isEmpty {
        Section {
          Text(
            "No corrections recorded yet. Click any extracted field in the main view to correct it."
          )
          .foregroundStyle(.secondary)
          .font(.body)
        }
      }

      if !correctionStore.corrections.isEmpty || !correctionStore.rules.isEmpty {
        Section {
          Button(role: .destructive) {
            showClearConfirmation = true
          } label: {
            Text("Clear All Corrections & Rules")
              .foregroundStyle(.red)
          }
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Corrections")
    .confirmationDialog(
      "Clear all corrections and rules?",
      isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("Clear All", role: .destructive) { correctionStore.clearAll() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This cannot be undone. The AI will no longer learn from past edits.")
    }
  }
}
```

- [ ] **Step 4: Build to verify**

Press **⌘B**. Expected: Build Succeeded.

- [ ] **Step 5: Run and test the Corrections settings section**

Press **⌘R**. Process a receipt, correct the vendor name. Then open Settings (⌘,) → Corrections:
- The corrected example should appear under "Examples"
- Correct the same vendor 3 times total — it should move to "Rules"
- Delete a rule — it should disappear
- "Clear All" should empty both lists after confirmation

- [ ] **Step 6: Commit**

```bash
git add macos/Sources/ReceiptSorterApp/ModernSettingsView.swift
git commit -m "feat: add Corrections settings section with examples and rules management"
```

---

## Self-review checklist

**Spec coverage:**
- [x] `Correction` struct with id, field, original, corrected, count, createdAt, updatedAt — Task 1
- [x] `Rule` struct with id, field, original, corrected, applyCount, promotedAt — Task 1
- [x] Persist to `~/Library/Application Support/ReceiptSorter/corrections.json` — Task 1
- [x] `record()` with deduplication and auto-promotion at count ≥ 3 — Task 2
- [x] `buildFewShotSnippet()` returning 5 most recent — Task 2
- [x] `applyRules()` case-insensitive matching on 5 string fields — Task 2
- [x] Delete correction / delete rule / clear all — Task 2
- [x] `CorrectionStore` lifted to app level as `@StateObject` — Task 3
- [x] `LocalLLMService` injects few-shot snippet before prompt — Task 3
- [x] `LocalLLMService` applies rules after extraction — Task 3
- [x] Click-to-edit inline with focus loss commit — Task 4
- [x] Pencil icon on hover, orange dot when corrected — Task 4/5
- [x] `applyCorrection` updates `items[index].data` and records to store — Task 5
- [x] Amount field editable but not recorded as a string correction — Task 5
- [x] Corrections section in Settings with separate Examples / Rules lists — Task 6
- [x] Delete individual correction / rule — Task 6
- [x] Clear All with confirmation — Task 6

**No placeholders:** confirmed — every step has complete code.

**Type consistency:** `Correction`, `Rule`, `CorrectionStore` names used consistently across all tasks. `applyCorrection(at:field:original:corrected:)` defined in Task 5 Step 2, referenced in Step 3.
