#!/usr/bin/env python3
"""
Launcher for the Receipt Sorter Web Application
"""
import uvicorn

if __name__ == "__main__":
    print("🚀 Starting Receipt Sorter Web App...")
    print("👉 Open your browser at: http://127.0.0.1:8000")
    uvicorn.run("src.receipt_sorter.web.app:app", host="127.0.0.1", port=8000, reload=True)
