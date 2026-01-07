#!/bin/bash

# Receipt Sorter - One-Click Launcher

# Get the directory where the script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "=========================================="
echo "   Receipt Sorter Launcher"
echo "=========================================="
echo ""

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found."
    echo "Please install Python from python.org"
    read -p "Press Enter to exit..."
    exit 1
fi

# Create Virtual Env if missing
if [ ! -d "venv" ]; then
    echo "📦 Setting up environment (first run only)..."
    python3 -m venv venv
    
    source venv/bin/activate
    
    echo "⬇️  Installing dependencies..."
    pip install --upgrade pip > /dev/null
    pip install -e . > /dev/null
else
    source venv/bin/activate
fi

# Check Tesseract
if ! command -v tesseract &> /dev/null; then
    echo "⚠️  Tesseract OCR not found."
    if command -v brew &> /dev/null; then
        echo "🍺 Installing Tesseract via Homebrew..."
        brew install tesseract
    else
        echo "❌ Please install Tesseract manually:"
        echo "   brew install tesseract"
    fi
fi

# Launch the app
echo ""
echo "🚀 Starting Web Server..."
echo "🌐 Opening browser..."

# Open browser in background after a short delay
(sleep 2 && open "http://127.0.0.1:8000") &

# Run the server
python run_web.py
