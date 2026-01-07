# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🚀 Major Features Added
- **Settings UI**: Implemented a new settings page (`/settings`) in the web application. Users can now configure their Gemini API Key, Google Sheet ID, and Service Account path directly through the browser. Changes are persisted to the `.env` file.
- **Docker Support**: Added `Dockerfile`, `docker-compose.yml`, and `.dockerignore`. The application can now be run entirely within a container, simplifying deployment and ensuring Tesseract OCR dependencies are met automatically.
- **Product Roadmap**: Created `ROADMAP.md` outlining the strategic shift to a native macOS application using Swift and Apple's Vision Framework.
- **Web Application**: Launched a local web interface using **FastAPI** and **Tailwind CSS**. Users can now drag-and-drop receipts for processing via `run_web.py`.
- **Gemini Integration**: Completely migrated the AI engine from Anthropic Claude to **Google Gemini**. Refactored `DataExtractor` and `Categorizer` to use `google-generativeai`.
- **Google Sheets Integration**: Implemented `GoogleSheetsManager` to sync receipt data to Google Sheets. Added `gspread` and `google-auth` dependencies.
- **Image Processing Support**: Enhanced `DocumentProcessor` (formerly `PDFProcessor`) to handle image files (JPG, PNG, etc.) using OCR, in addition to PDFs.
- **Project Restructuring**: Refactored the entire codebase into a standard Python package structure:
    - Moved source code to `src/receipt_sorter/`.
    - Moved tests to `tests/`.
    - Moved documentation to `docs/`.
    - Added `pyproject.toml` for modern packaging.
    - Added `run.py` (CLI) and `run_web.py` (Web) entry points.

### 🛠️ Improvements & Fixes
- **Configuration**: Updated `config.py` and `.env.example` to support Gemini API keys and Google Sheets credentials.
- **File Organization**: Improved `FileOrganizer` to preserve original file extensions.
- **Testing**: Added `test_google_sheets.py` to verify cloud connectivity.
- **Documentation**: Updated `README.md` to reflect new features (Gemini, Web App), installation steps, and project structure. Added `LICENSE` (MIT).

### 📦 Dependencies
- Added `google-generativeai`, `fastapi`, `uvicorn`, `python-multipart`, `jinja2`.
- Added `gspread` and `google-auth`.
- Removed `anthropic`.
- Configured project as an editable package (`pip install -e .`).

---
