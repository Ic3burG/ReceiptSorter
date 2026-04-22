# Gemma 4 Migration Design

**Date:** 2026-04-22
**Status:** Approved

## Overview

Migrate Receipt Sorter to use Gemma 4 as the sole AI engine, removing all other model paths (Gemini cloud API, Llama presets, custom model picker). Apple Vision is retained for OCR (image/PDF → text). Gemma 4 handles all structured data extraction from that text. The model ID is centralized in a single constant so future model upgrades are a one-line change.

## Decisions

- **Apple Vision kept** for OCR: fast, accurate on clean printed receipts, handles PDF text layers natively, low memory footprint, does not compete with the 3GB Gemma 4 model for GPU resources.
- **Gemma 4 vision not used** for direct image input: speed and reliability on typical receipts does not justify the context-window cost and latency.
- **Model locked in UI**: no picker, no custom model field. Users see an informational label only.
- **Model ID centralized**: single `GemmaModel` enum in core; all services and views reference it.
- **Approach: Big Bang** — all changes land in one pass. Codebase is small enough that a single clean diff is preferable to multiple transitional PRs.

## Architecture

### Pipeline (unchanged)

```
Receipt file (image or PDF)
    → OCRService (Apple Vision)        [text extraction]
    → LocalLLMService (Gemma 4 / MLX)  [structured data extraction]
    → ReceiptData
    → Export (Excel / Google Sheets / File Organization)
```

### What Changes

| Component | Action | Notes |
|---|---|---|
| `GemmaModel.swift` | **Create** | Single source of truth for model ID, display name, size |
| `GeminiService.swift` | **Delete** | Cloud extractor and all request/response structs removed |
| `ReceiptData` struct | **Move** | Out of `GeminiService.swift` → into `ReceiptSorterCore.swift` |
| `LocalLLMService.swift` | **Update** | Reference `GemmaModel.modelId` constant |
| `ModelDownloadService.swift` | **Update** | Reference `GemmaModel.sizeEstimateBytes` constant |
| `ReceiptSorterCore.swift` | **Update** | Simplified init, always creates `LocalLLMService`, removes Gemini fallback logic |
| `ContentView.swift` | **Update** | Remove `geminiApiKey`, `useLocalLLM`, `localModelId` AppStorage keys and their observers |
| `ModernSettingsView.swift` | **Update** | Remove model picker, Gemini key field, toggle; show Gemma 4 info label |
| `OnboardingView.swift` | **Update** | Remove cloud toggle and Gemini key step; simplify to HF token + download |
| `ModelDownloadBanner.swift` | **No change** | Already model-agnostic |
| `OCRService.swift` | **No change** | Apple Vision pipeline retained as-is |

### What Stays

- `ReceiptDataExtractor` protocol — `extractData(from text: String)` signature is unchanged
- `OCRService` — Apple Vision text recognition, unchanged
- `LocalLLMService` — inference logic, prompt, JSON parsing, all unchanged
- `ModelDownloadService` — download/progress logic, unchanged
- All export services (`SheetService`, `ExcelService`, `FileOrganizationService`)

## New File: GemmaModel.swift

```swift
// Single source of truth for the Gemma 4 model configuration.
// To upgrade to a future model, change these three values.
enum GemmaModel {
    static let modelId = "mlx-community/gemma-4-e4b-it-4bit"
    static let displayName = "Gemma 4"
    static let sizeEstimateBytes: Int64 = 3_000_000_000
}
```

## Core Layer Changes

### ReceiptSorterCore.swift

- `ReceiptData` struct moves here from `GeminiService.swift`
- `init` parameters `apiKey` and `localLLMService` removed; `clientID`, `clientSecret`, `sheetID` retained (Google Sheets auth, unrelated to Gemini)
- `init` always creates `LocalLLMService(modelId: GemmaModel.modelId)`
- Fallback conditional (`if let localLLMService … else if let apiKey …`) replaced with direct assignment
- `GeminiError.notConfigured` extension removed
- `extractReceiptData` and all export/organize methods unchanged

### LocalLLMService.swift

- `init(modelId:)` default value changes from hardcoded string to `GemmaModel.modelId`
- No other changes

### ModelDownloadService.swift

- `modelSizeEstimate` hardcoded value replaced with `GemmaModel.sizeEstimateBytes`
- No other changes

## UI Layer Changes

### ContentView.swift

- Remove `@AppStorage("geminiApiKey")`, `@AppStorage("useLocalLLM")`, `@AppStorage("localModelId")`
- Remove `onChange` observers for those keys
- `initializeCore()` always creates `LocalLLMService(modelId: GemmaModel.modelId)` — no conditional branch
- `ReceiptSorterCore` init call simplified to remove API key and toggle parameters

### ModernSettingsView.swift (GeneralSettingsDetailView)

- Remove `ModelOption` enum (Llama preset, custom option)
- Remove model `Picker` and custom model ID `TextField`
- Remove `geminiApiKey` field and cloud footer text
- Remove `useLocalLLM` toggle
- AI section shows: Hugging Face token field + informational label ("Gemma 4 · ~3GB · Runs entirely on your device") + download status

### OnboardingView.swift

- Remove `useLocalLLM` binding and toggle from `ConfigurationStep`
- Remove Gemini API key field and its conditional branch
- `ConfigurationStep` becomes: HF token entry + model download trigger + download progress

## AppStorage Keys Removed

| Key | Previously used for |
|---|---|
| `geminiApiKey` | Gemini API cloud access |
| `useLocalLLM` | Toggle between local and cloud |
| `localModelId` | User-selected model ID |

The `hfToken` key is retained (still needed for HuggingFace downloads).

## Out of Scope

- Gemma 4 vision (direct image input) — not pursued; Apple Vision OCR retained
- PDF rasterization changes — existing PDFKit pipeline unchanged
- Any changes to export services, auth, or file organization
