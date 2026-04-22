# Correction & Learning System Design

## Goal

Allow users to correct mistakes in extracted receipt data (wrong vendor, currency, etc.) and have the app improve over time by learning from those corrections.

## Architecture

Two learning mechanisms work together:

- **Few-shot injection (Approach A):** Recent corrections are injected into the LLM system prompt as examples before each extraction. The model generalises from them.
- **Rule-based post-processing (Approach B):** High-confidence corrections (seen ≥ 3 times) are promoted to Rules and applied deterministically after extraction, guaranteeing correctness for repeat patterns.

---

## Data Model

Persisted to `~/Library/Application Support/ReceiptSorter/corrections.json` as a single `CorrectionStore` document.

### Correction

A single observed fix recorded when a user edits a field.

```swift
struct Correction: Codable, Identifiable {
    let id: UUID
    let field: String       // "vendor" | "currency" | "category" | "date" | "total_amount" | "description"
    let original: String    // value the model produced
    let corrected: String   // value the user typed
    var count: Int          // how many times this exact pair has been seen
    let createdAt: Date
    var updatedAt: Date
}
```

### Rule

A high-confidence mapping auto-promoted from Corrections when `count >= 3`. Applied deterministically after every extraction.

```swift
struct Rule: Codable, Identifiable {
    let id: UUID
    let field: String
    let original: String    // case-insensitive match key
    let corrected: String
    var applyCount: Int     // how many times this rule has fired
    let promotedAt: Date
}
```

Deleting a Rule demotes it — the underlying Corrections are retained. Deleting all Corrections for a (field, original→corrected) pair also removes the Rule if one exists.

---

## CorrectionStore

New file: `Sources/ReceiptSorterCore/CorrectionStore.swift`

`@MainActor public class CorrectionStore: ObservableObject`

### Properties

```swift
@Published public private(set) var corrections: [Correction]
@Published public private(set) var rules: [Rule]
```

### Public API

```swift
// Record a user edit. Creates or increments a Correction; auto-promotes to Rule at count == 3.
public func record(field: String, original: String, corrected: String)

// Returns up to 5 most recent corrections formatted as a prompt snippet.
// Returns nil if no corrections exist yet.
public func buildFewShotSnippet() -> String?

// Applies all Rules to an extracted ReceiptData. Returns the (possibly modified) data.
public func applyRules(to data: ReceiptData) -> ReceiptData

// Management
public func deleteCorrection(id: UUID)
public func deleteRule(id: UUID)
public func clearAll()
```

### Persistence

Loads from disk on `init()`. Writes to disk on every mutation (synchronous JSON encode + `Data.write`). The file is created on first write if it does not exist.

### Promotion logic

When `record(field:original:corrected:)` increments a Correction's count to exactly 3, it creates a Rule with `applyCount = 0` and saves both lists.

---

## Few-Shot Snippet Format

`buildFewShotSnippet()` returns a string injected at the top of the system prompt, before the JSON schema:

```
Past corrections (apply these patterns to new receipts):
- vendor: "Mcdonalds" → "McDonald's"
- currency: "USD" → "CAD"
- vendor: "Tims" → "Tim Hortons"
```

Selection: the 5 most recently updated Corrections, sorted by `updatedAt` descending. If `corrections` is empty, returns `nil` and nothing is injected.

Token budget: ~10 tokens per correction × 5 = ~50 tokens added to every prompt. Well within Gemma 4's 131K context window.

---

## Rule Application

`applyRules(to:)` checks each of the six `ReceiptData` fields against the Rule table using a case-insensitive string comparison on the `original` value. Returns a new `ReceiptData` with matched fields replaced. Unmatched fields are returned unchanged.

---

## LocalLLMService Changes

`LocalLLMService` gains a `nonisolated(unsafe) let correctionStore: CorrectionStore` property (passed in at init). `LocalLLMService` is a Swift `actor`; `correctionStore` is `@MainActor`. Calls to `correctionStore` inside `LocalLLMService` are made via `await MainActor.run { ... }`, matching the existing pattern in `processItem` in `ContentView`.

`extractData(from:)` is updated:

1. **Before LLM call:** if `correctionStore.buildFewShotSnippet()` returns a non-nil string, prepend it to the system prompt.
2. **After LLM call:** pass extracted data through `correctionStore.applyRules(to:)` before returning.

---

## ReceiptSorterCore Changes

`ReceiptSorterCore` gains a `public let correctionStore: CorrectionStore` property, initialised in `init()` and passed into `LocalLLMService`.

---

## UI Changes

### EditableDataCard

`DataCard` is replaced by `EditableDataCard` with two display states:

- **Display:** shows value as `Text`. On hover, a pencil icon (`pencil`) appears trailing. A small amber dot (`.foregroundColor(.orange)`) appears if this field has been corrected in the current session.
- **Edit:** on tap, swaps to `TextField` pre-filled with the current value. Commits on Return key (`onSubmit`) or focus loss (`onChange(of: isFocused)`).

On commit, `ContentView` calls `correctionStore.record(field:original:corrected:)` and updates `items[index].data` with the new value.

### Corrections Settings Section

New section in `ModernSettingsView` — "Learned Corrections" — shown as a tab or a collapsible group.

**Examples list:** each row shows `field · "original" → "corrected"` with a trash button. Sorted by `updatedAt` descending.

**Rules list:** each row shows `field · "original" → "corrected"` with an `applyCount` badge ("applied N times") and a trash button. Sorted by `applyCount` descending.

**Clear All button:** wipes both lists after a confirmation alert.

---

## File Map

| File | Action |
|------|--------|
| `Sources/ReceiptSorterCore/CorrectionStore.swift` | Create |
| `Sources/ReceiptSorterCore/ReceiptSorterCore.swift` | Add `correctionStore` property |
| `Sources/ReceiptSorterCore/LocalLLMService.swift` | Accept `correctionStore`, inject few-shot, apply rules |
| `Sources/ReceiptSorterApp/ContentView.swift` | Replace `DataCard` with `EditableDataCard`, call `correctionStore.record` on commit |
| `Sources/ReceiptSorterApp/EditableDataCard.swift` | Create |
| `Sources/ReceiptSorterApp/ModernSettingsView.swift` | Add Learned Corrections section |

---

## Error Handling

- Disk write failures are logged via `NSLog` and silently swallowed — a missed persistence write is recoverable; crashing is not.
- If `corrections.json` is corrupt on load, `CorrectionStore` starts empty and overwrites the file on next write.
- Editing a field to the same value as the original produces no correction (guarded by `original != corrected`). All field values — including `total_amount` — are stored as their String representation for matching and display purposes. `total_amount` corrections are not applied by the rule engine (the model already outputs numbers reliably); rule matching covers only the five String-typed fields: vendor, currency, category, date, description.
