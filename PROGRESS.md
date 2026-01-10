# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 10, 2026

### 📁 File Organization Feature

- **FileOrganizationService**: New service that automatically organizes receipts into `YYYY/MM/` folder structure based on receipt date.
- **Organization Settings Tab**: Added settings UI with folder picker, auto-organize toggle, and help text explaining the folder structure.
- **Auto-organize after export**: Files are automatically moved to year/month folders after successful Excel export.

### 🔍 Duplicate Receipt Review Feature

- **Conflict Detection**: `organizeReceiptWithConflictDetection()` method detects filename collisions instead of auto-renaming.
- **Side-by-Side Comparison UI**: New `DuplicateReviewView` shows existing and new files with PDF/image previews and file metadata.
- **User Resolution Options**: Three choices when duplicates are detected:
  - Keep Existing (don't move new file)
  - Keep Both (move with unique suffix)
  - Replace (delete existing, move new file)
- **FileMetadata struct**: Displays filename, modification date, and file size in comparison UI.

---

## Session: January 6, 2026

### 🛠️ CI/CD Improvements

- **CI Stability Fix**: Downgraded `swift-tools-version` to `5.10` and reverted GitHub Actions runners to `macos-14`. This ensures the CI environment (Xcode 15.4) matches the package requirements, eliminating "tools version mismatch" errors while maintaining concurrency safety.

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
- **Google Sheets Integration**: Implemented `SheetService`.
- **Gemini Swift Integration**: Implemented `GeminiService`.
- **Full macOS Pipeline**: Drop -> OCR -> AI -> UI -> Sync.
- **Native SwiftUI App**: Implemented `ReceiptSorterApp`.
- **Native OCR**: Implemented `OCRService` using Vision.

---
