# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🛠️ CI/CD Improvements
- **GitHub Actions Fix**: Downgraded macOS runner from `macos-15` (beta) to `macos-14` (stable) to ensure reliable Swift builds.
- **Build Script Robustness**: Added dynamic build path discovery to `bundle.sh` to handle varying Swift Package Manager output layouts in CI environments.
- **Dependency Installation**: Added `create-dmg` installation step to the CI workflow.

### 🛠️ UX Improvements
- **Spreadsheet Formatting**: Added a "Apply Professional Formatting" button to the Settings window.
- **Robust Spreadsheet Link Parsing**: Updated `SettingsView` to accept full Google Sheets URLs.
- **Authentication Visibility**: Added a persistent status indicator at the bottom of the sidebar.
- **Sign Out Capability**: Added a "Sign Out" button.

### 🚀 Phase 3 Progress (Distribution)
- **App Icon Generation**: Designed and implemented a professional macOS app icon.
- **Build Script**: Created `macos/scripts/bundle.sh` for automated packaging.

### 🚀 Phase 2 Progress (Native macOS App)
- **Batch Processing**: Implemented robust multi-file queuing and processing.
- **Completed Sync Pipeline**: Wired up the "Sync to Sheets" button.
- **UI Polish & Architecture**: Settings Window, Live Preview, Visual Feedback.
- **Google Sheets Integration**: Implemented `SheetService`.
- **Gemini Swift Integration**: Implemented `GeminiService`.
- **Full macOS Pipeline**: Drop -> OCR -> AI -> UI -> Sync.
- **Native SwiftUI App**: Implemented `ReceiptSorterApp`.
- **Native OCR**: Implemented `OCRService` using Vision.

---