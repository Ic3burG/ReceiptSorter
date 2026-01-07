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
    # Get stats or recent files if possible
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/upload")
async def upload_files(request: Request, files: List[UploadFile] = File(...)):
    """Handle file uploads and processing"""
    results = []
    
    # Ensure upload directory exists
    upload_dir = Path(config.SOURCE_FOLDER)
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    for file in files:
        try:
            # Save file temporarily
            file_path = upload_dir / file.filename
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
                
            # Process the file
            result = process_single_file(str(file_path))
            results.append(result)
            
        except Exception as e:
            results.append({
                "filename": file.filename,
                "status": "error",
                "message": str(e)
            })
            
    return templates.TemplateResponse("results.html", {"request": request, "results": results})

def process_single_file(file_path: str) -> dict:
    """Process a single file using the existing logic"""
    try:
        # 1. Validate
        if not processor.validate_file(file_path):
            return {"filename": os.path.basename(file_path), "status": "error", "message": "Invalid file"}

        # 2. Extract Text
        text = processor.extract_text(file_path)
        if not text:
            return {"filename": os.path.basename(file_path), "status": "error", "message": "No text extracted"}

        # 3. Extract Data
        data = extractor.extract_receipt_data(text)
        if not data:
            return {"filename": os.path.basename(file_path), "status": "error", "message": "Data extraction failed"}

        # 4. Categorize
        cat_result = categorizer.categorize_receipt(data)
        category = cat_result.get('category', 'Other')
        confidence = cat_result.get('confidence', 0)
        needs_review = categorizer.needs_review(confidence)

        # 5. Organize
        organized_path = organizer.organize_receipt(file_path, data, needs_review)
        
        # 6. Update Spreadsheets
        if spreadsheet_mgr:
            spreadsheet_mgr.add_receipt_entry(data, category, confidence, organized_path)
            
        if gs_mgr:
            gs_mgr.add_receipt_entry(data, category, confidence, organized_path)

        return {
            "filename": os.path.basename(file_path),
            "status": "success",
            "data": data,
            "category": category,
            "confidence": confidence,
            "organized_path": organized_path,
            "needs_review": needs_review
        }

    except Exception as e:
        return {"filename": os.path.basename(file_path), "status": "error", "message": str(e)}

def start():
    """Entry point to run the server"""
    uvicorn.run("receipt_sorter.web.app:app", host="127.0.0.1", port=8000, reload=True)

if __name__ == "__main__":
    start()
