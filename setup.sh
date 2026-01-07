#!/bin/bash

# Receipt Sorter Setup Script
# This script helps set up the Receipt Sorter application

echo "=================================================="
echo "  Receipt Sorter & Categorization App - Setup"
echo "=================================================="
echo ""

# Check Python version
echo "🔍 Checking Python version..."
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "   Found: Python $python_version"

# Create virtual environment
echo ""
echo "🐍 Creating virtual environment..."
if [ -d "venv" ]; then
    echo "   Virtual environment already exists"
else
    python3 -m venv venv
    echo "   ✓ Virtual environment created"
fi

# Activate virtual environment
echo ""
echo "🔌 Activating virtual environment..."
source venv/bin/activate
echo "   ✓ Virtual environment activated"

# Install dependencies
echo ""
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -e .
echo "   ✓ Dependencies installed"

# Check for Tesseract
echo ""
echo "🔍 Checking for Tesseract OCR..."
if command -v tesseract &> /dev/null; then
    tesseract_version=$(tesseract --version 2>&1 | head -n 1)
    echo "   ✓ $tesseract_version"
else
    echo "   ⚠️  Tesseract not found"
    echo "   Please install Tesseract OCR:"
    echo "   - macOS: brew install tesseract"
    echo "   - Ubuntu: sudo apt-get install tesseract-ocr"
fi

# Set up .env file
echo ""
echo "🔑 Setting up environment variables..."
if [ -f ".env" ]; then
    echo "   .env file already exists"
else
    cp .env.example .env
    echo "   ✓ Created .env file from template"
    echo ""
    echo "   ⚠️  IMPORTANT: Edit .env and add your ANTHROPIC_API_KEY"
    echo "   Get your API key from: https://console.anthropic.com/"
fi

# Create default folders
echo ""
echo "📁 Creating default folders..."
mkdir -p ~/receipts/source
mkdir -p ~/receipts/sorted
echo "   ✓ Created ~/receipts/source (put your PDF receipts here)"
echo "   ✓ Created ~/receipts/sorted (organized receipts will go here)"

echo ""
echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Edit .env and add your ANTHROPIC_API_KEY"
echo "2. Place PDF receipts in ~/receipts/source/"
echo "3. Run: python run.py"
echo ""
echo "To activate the virtual environment in future sessions:"
echo "   source venv/bin/activate"
echo ""
