"""
FastAPI Web Application for Receipt Sorter
"""

import os
import shutil
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, HTTPException, Request, Form
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, RedirectResponse
import uvicorn
from pathlib import Path

# Import core logic
from .. import config
from ..pdf_processor import DocumentProcessor
from ..data_extractor import DataExtractor
from ..categorizer import Categorizer
from ..file_organizer import FileOrganizer
from ..spreadsheet_manager import SpreadsheetManager
from ..google_sheets_manager import GoogleSheetsManager

app = FastAPI(title="Receipt Sorter")

# Mount static files
static_path = Path(__file__).parent / "static"
app.mount("/static", StaticFiles(directory=str(static_path)), name="static")

# Templates
templates_path = Path(__file__).parent / "templates"
templates = Jinja2Templates(directory=str(templates_path))

# Initialize services
# Note: These are initialized lazily or on startup to handle env vars
processor = None
extractor = None
categorizer = None
organizer = None
spreadsheet_mgr = None
gs_mgr = None

@app.on_event("startup")
async def startup_event():
    global processor, extractor, categorizer, organizer, spreadsheet_mgr, gs_mgr
    try:
        processor = DocumentProcessor()
        extractor = DataExtractor()
        categorizer = Categorizer()
        organizer = FileOrganizer()
        spreadsheet_mgr = SpreadsheetManager()
        gs_mgr = GoogleSheetsManager()
        print("Services initialized successfully")
    except Exception as e:
        print(f"Error initializing services: {e}")

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    """Render the main dashboard"""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/settings", response_class=HTMLResponse)
async def get_settings(request: Request):
    """Render the settings page"""
    from dotenv import dotenv_values
    current_env = dotenv_values(".env")
    return templates.TemplateResponse("settings.html", {
        "request": request,
        "gemini_api_key": current_env.get("GEMINI_API_KEY", ""),
        "google_sheet_id": current_env.get("GOOGLE_SHEET_ID", ""),
        "service_account_file": current_env.get("GOOGLE_SERVICE_ACCOUNT_FILE", "service_account.json")
    })

@app.post("/settings")
async def save_settings(
    request: Request,
    gemini_api_key: str = Form(...),
    google_sheet_id: str = Form(...),
    service_account_file: str = Form(...)
):
    """Save settings to .env file"""
    try:
        env_path = Path(".env")
        # Read existing lines to preserve comments or other vars
        lines = []
        if env_path.exists():
            with open(env_path, "r") as f:
                lines = f.readlines()
        
        # Update or add keys
        new_values = {
            "GEMINI_API_KEY": gemini_api_key,
            "GOOGLE_SHEET_ID": google_sheet_id,
            "GOOGLE_SERVICE_ACCOUNT_FILE": service_account_file
        }
        
        updated_lines = []
        keys_handled = set()
        
        for line in lines:
            stripped = line.strip()
            if stripped and "=" in stripped and not stripped.startswith("#"):
                key = stripped.split("=")[0]
                if key in new_values:
                    updated_lines.append(f"{key}={new_values[key]}\n")
                    keys_handled.add(key)
                    continue
            updated_lines.append(line)
            
        for key, value in new_values.items():
            if key not in keys_handled:
                updated_lines.append(f"{key}={value}\n")
        
        with open(env_path, "w") as f:
            f.writelines(updated_lines)
            
        # Reload environment and re-init services
        os.environ["GEMINI_API_KEY"] = gemini_api_key
        os.environ["GOOGLE_SHEET_ID"] = google_sheet_id
        os.environ["GOOGLE_SERVICE_ACCOUNT_FILE"] = service_account_file
        await startup_event()
        
        return templates.TemplateResponse("settings.html", {
            "request": request,
            "message": "Settings saved successfully!",
            "gemini_api_key": gemini_api_key,
            "google_sheet_id": google_sheet_id,
            "service_account_file": service_account_file
        })
    except Exception as e:
        return templates.TemplateResponse("settings.html", {
            "request": request,
            "error": str(e),
            "gemini_api_key": gemini_api_key,
            "google_sheet_id": google_sheet_id,
            "service_account_file": service_account_file
        })

@app.post("/upload")
async def upload_files(request: Request, files: List[UploadFile] = File(...)):
    """Handle file uploads and return extracted data for review"""
    results = []
    upload_dir = Path(config.SOURCE_FOLDER)
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    for file in files:
        try:
            file_path = upload_dir / file.filename
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
                
            # Step 1: Extract only (no syncing yet)
            result = extract_only(str(file_path))
            results.append(result)
        except Exception as e:
            results.append({"filename": file.filename, "status": "error", "message": str(e)})
            
    return templates.TemplateResponse("review.html", {"request": request, "results": results})

@app.post("/confirm")
async def confirm_batch(request: Request):
    """Finalize the batch after user review and sync to spreadsheets"""
    form_data = await request.form()
    
    # Group form data by index
    batch = {}
    for key, value in form_data.items():
        if '[' in key and ']' in key:
            index = key.split('[')[1].split(']')[0]
            field = key.split('[')[0]
            if index not in batch:
                batch[index] = {}
            batch[index][field] = value

    sync_results = []
    for index, data in batch.items():
        try:
            # Prepare data for finalization
            receipt_data = {
                "vendor": data.get("vendor"),
                "date": data.get("date"),
                "total_amount": float(data.get("amount", 0)),
                "currency": data.get("currency"),
                "description": data.get("description", "")
            }
            category = data.get("category")
            confidence = int(data.get("confidence", 100))
            file_path = data.get("file_path")
            
            # Step 2: Finalize (organize and sync)
            result = finalize_processing(file_path, receipt_data, category, confidence)
            sync_results.append(result)
        except Exception as e:
            sync_results.append({"filename": data.get("filename"), "status": "error", "message": str(e)})

    return templates.TemplateResponse("sync_results.html", {"request": request, "results": sync_results})

def extract_only(file_path: str) -> dict:
    """Perform initial extraction and categorization without saving to spreadsheets"""
    try:
        if not processor.validate_file(file_path):
            return {"filename": os.path.basename(file_path), "status": "error", "message": "Invalid file"}

        text = processor.extract_text(file_path)
        if not text:
            return {"filename": os.path.basename(file_path), "status": "error", "message": "No text extracted"}

        data = extractor.extract_receipt_data(text)
        if not data:
            return {"filename": os.path.basename(file_path), "status": "error", "message": "Extraction failed"}

        cat_result = categorizer.categorize_receipt(data)
        
        return {
            "filename": os.path.basename(file_path),
            "file_path": file_path,
            "status": "success",
            "data": data,
            "category": cat_result.get('category', 'Other'),
            "confidence": cat_result.get('confidence', 0),
            "needs_review": categorizer.needs_review(cat_result.get('confidence', 0)),
            "all_categories": config.TAX_CATEGORIES
        }
    except Exception as e:
        return {"filename": os.path.basename(file_path), "status": "error", "message": str(e)}

def finalize_processing(file_path: str, data: dict, category: str, confidence: int) -> dict:
    """Organize file and sync to spreadsheets after review"""
    try:
        needs_review = categorizer.needs_review(confidence)
        organized_path = organizer.organize_receipt(file_path, data, needs_review)
        
        if spreadsheet_mgr:
            spreadsheet_mgr.add_receipt_entry(data, category, confidence, organized_path)
        if gs_mgr:
            gs_mgr.add_receipt_entry(data, category, confidence, organized_path)

        return {
            "filename": os.path.basename(file_path),
            "status": "success",
            "vendor": data["vendor"],
            "amount": data["total_amount"],
            "category": category
        }
    except Exception as e:
        return {"filename": os.path.basename(file_path), "status": "error", "message": str(e)}

def start():
    """Entry point to run the server"""
    uvicorn.run("receipt_sorter.web.app:app", host="127.0.0.1", port=8000, reload=True)

if __name__ == "__main__":
    start()
