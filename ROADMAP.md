# Product Roadmap

This document outlines the development trajectory for Receipt Sorter, focusing on its evolution from a local Python web tool to a native macOS application.

## 🏁 Current Status
- **Core Engine**: Python-based (Gemini AI + Tesseract OCR).
- **Interface**: Local Web App (FastAPI + Tailwind CSS).
- **Storage**: Local Files + Google Sheets.

## 📅 Phase 1: Web App Refinement (Immediate)
*Goal: Polish the current Python implementation.*
- [x] **Docker Support**: Containerize the application for easy deployment without managing Python environments.
- [x] **Settings UI**: Allow users to configure API keys and target Google Sheets directly from the web interface.
- [x] **Batch Editing**: Allow users to manually correct categories or amounts before syncing to Google Sheets.
- [x] **Visual Feedback**: Add progress bars for uploading and processing large batches.
- [x] **User Onboarding**: Added a Setup Wizard and `start_app.command` for one-click installation and configuration.

## 🍎 Phase 2: Native macOS App (The Swift Transition)
*Goal: Rebuild the application as a high-performance, native macOS utility.*

We will migrate from **Python** to **Swift**, replacing external dependencies with native macOS frameworks for better performance and user experience.

### Architecture Shift

| Feature | Current (Python) | Future (Swift) | Key Advantage |
| :--- | :--- | :--- | :--- |
| **Language** | Python 3 | Swift 6 | Native performance, type safety |
| **OCR Engine** | Tesseract (Requires Install) | **Apple Vision Framework** | Built-in to macOS (no setup), faster, higher accuracy |
| **AI Engine** | Gemini Python SDK | **Gemini Swift SDK** | Direct integration |
| **Spreadsheets**| gspread Library | Google Sheets REST API | Standard OAuth 2.0 flow |
| **UI** | Browser (HTML/CSS) | **SwiftUI** | Native Drag & Drop, System Integration, Dark Mode |

### 🛠️ Technical Plan (Using Swift CLI & SPM)

We will structure the project using **Swift Package Manager (SPM)** to modularize the code, allowing us to build both a CLI tool and a GUI app from the same core logic.

#### Step 1: Core Logic Package (`ReceiptSorterCore`)
Create a pure Swift package to handle the business logic.
- **Command**: `swift package init --type library --name ReceiptSorterCore`
- **Modules**:
    - `OCRService`: Wraps `VNRecognizeTextRequest` (Vision Framework) to extract text from Images and PDFs.
    - `GeminiService`: interacting with Google's Generative AI REST API or Swift SDK.
    - `SheetService`: Handles OAuth2 and Google Sheets API calls.

#### Step 2: Swift CLI Tool
Build a command-line interface to verify the core logic without a UI.
- **Command**: `swift package init --type executable --name receipt-cli`
- **Functionality**: `receipt-cli process ~/Downloads/receipt.pdf`
- **Goal**: Verify OCR and API connectivity in isolation.

#### Step 3: macOS UI (SwiftUI)
Build the visual application that consumes `ReceiptSorterCore`.
- **Setup**: standard macOS App structure (`.xcodeproj`).
- **Features**:
    - **Drop Zone**: Native drag-and-drop target in the window.
    - **Live Preview**: PDF/Image viewer using `PDFKit` and SwiftUI.
    - **Menu Bar**: Optional "Menu Bar App" mode for quick access.
    - **Native Notifications**: Notify when processing completes.

### 📦 Phase 3: Distribution
- **Signing**: Code sign with Apple Developer ID.
- **Notarization**: Submit to Apple Notary Service (can be done via `xcrun notarytool` CLI).
- **Packaging**: Create a `.dmg` for distribution.

## 🔮 Future Ideas
- **Mobile Companion**: iOS App sharing the same `ReceiptSorterCore`.
- **Shortcuts Support**: Integation with macOS Shortcuts app for automation.
- **Watch Folders**: Background daemon that watches a folder and auto-processes new files.
