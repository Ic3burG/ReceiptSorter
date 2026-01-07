#!/usr/bin/env python3
"""
Test Setup Script
Validates that all dependencies and configuration are correct
"""

import sys
import os

# Add src to path
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src'))

def test_imports():
    """Test that all required libraries can be imported"""
    print("🧪 Testing imports...")

    required_modules = {
        'pdfplumber': 'pdfplumber',
        'pypdf2': 'PyPDF2',
        'pytesseract': 'pytesseract',
        'PIL': 'Pillow',
        'anthropic': 'anthropic',
        'openpyxl': 'openpyxl',
        'pandas': 'pandas',
        'dotenv': 'python-dotenv',
        'dateutil': 'python-dateutil'
    }

    failed = []
    for module_name, package_name in required_modules.items():
        try:
            __import__(module_name)
            print(f"   ✓ {package_name}")
        except ImportError as e:
            print(f"   ❌ {package_name} - {str(e)}")
            failed.append(package_name)

    if failed:
        print(f"\n❌ Missing packages: {', '.join(failed)}")
        print(f"   Run: pip install {' '.join(failed)}")
        return False
    else:
        print("   ✅ All imports successful!")
        return True


def test_tesseract():
    """Test Tesseract OCR installation"""
    print("\n🧪 Testing Tesseract OCR...")

    try:
        import pytesseract
        from PIL import Image

        # Try to get Tesseract version
        version = pytesseract.get_tesseract_version()
        print(f"   ✓ Tesseract version: {version}")
        return True
    except Exception as e:
        print(f"   ⚠️  Tesseract not properly configured: {str(e)}")
        print("   Please install Tesseract OCR:")
        print("   - macOS: brew install tesseract")
        print("   - Ubuntu: sudo apt-get install tesseract-ocr")
        print("   - Windows: https://github.com/UB-Mannheim/tesseract/wiki")
        return False


def test_api_key():
    """Test that API key is configured"""
    print("\n🧪 Testing API key configuration...")

    from dotenv import load_dotenv
    load_dotenv()

    api_key = os.getenv("ANTHROPIC_API_KEY")

    if not api_key:
        print("   ❌ ANTHROPIC_API_KEY not found in environment")
        print("   Please create a .env file with your API key")
        print("   Example: ANTHROPIC_API_KEY=sk-ant-...")
        return False
    elif api_key == "your-api-key-here":
        print("   ❌ ANTHROPIC_API_KEY is still set to placeholder value")
        print("   Please edit .env and add your actual API key")
        print("   Get your key from: https://console.anthropic.com/")
        return False
    else:
        masked_key = api_key[:10] + "..." + api_key[-4:] if len(api_key) > 14 else "***"
        print(f"   ✓ API key found: {masked_key}")
        return True


def test_api_connection():
    """Test connection to Anthropic API"""
    print("\n🧪 Testing API connection...")

    try:
        from dotenv import load_dotenv
        import anthropic

        load_dotenv()
        api_key = os.getenv("ANTHROPIC_API_KEY")

        if not api_key or api_key == "your-api-key-here":
            print("   ⏭️  Skipping (API key not configured)")
            return False

        client = anthropic.Anthropic(api_key=api_key)

        # Try a minimal API call
        message = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=10,
            messages=[
                {"role": "user", "content": "Hi"}
            ]
        )

        print(f"   ✓ API connection successful!")
        print(f"   ✓ Model: claude-3-5-sonnet-20241022")
        return True

    except Exception as e:
        print(f"   ❌ API connection failed: {str(e)}")
        print("   Please check your API key and internet connection")
        return False


def test_folders():
    """Test that required folders exist"""
    print("\n🧪 Testing folder structure...")

    from receipt_sorter import config

    folders_to_check = [
        (config.SOURCE_FOLDER, "Source folder"),
        (config.OUTPUT_BASE_FOLDER, "Output folder")
    ]

    all_exist = True
    for folder, description in folders_to_check:
        if os.path.exists(folder):
            print(f"   ✓ {description}: {folder}")
        else:
            print(f"   ⚠️  {description} does not exist: {folder}")
            print(f"      Will be created automatically when needed")

    return True


def test_application_modules():
    """Test that application modules can be imported"""
    print("\n🧪 Testing application modules...")

    modules = [
        'receipt_sorter.config',
        'receipt_sorter.pdf_processor',
        'receipt_sorter.data_extractor',
        'receipt_sorter.categorizer',
        'receipt_sorter.file_organizer',
        'receipt_sorter.spreadsheet_manager'
    ]

    failed = []
    for module in modules:
        try:
            __import__(module)
            print(f"   ✓ {module}")
        except ImportError as e:
            print(f"   ❌ {module} - {str(e)}")
            failed.append(module)

    if failed:
        print(f"\n❌ Failed to import: {', '.join(failed)}")
        return False
    else:
        print("   ✅ All application modules loaded successfully!")
        return True


def main():
    """Run all tests"""
    print("=" * 70)
    print("   RECEIPT SORTER - SETUP VALIDATION")
    print("=" * 70)
    print()

    results = {
        'imports': test_imports(),
        'tesseract': test_tesseract(),
        'api_key': test_api_key(),
        'api_connection': test_api_connection(),
        'folders': test_folders(),
        'modules': test_application_modules()
    }

    print("\n" + "=" * 70)
    print("   RESULTS")
    print("=" * 70)
    print()

    total = len(results)
    passed = sum(1 for v in results.values() if v)

    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"   {status} - {test_name}")

    print()
    print(f"   {passed}/{total} tests passed")
    print()

    if passed == total:
        print("   🎉 All tests passed! You're ready to process receipts.")
        print("   Run: python run.py")
    else:
        print("   ⚠️  Some tests failed. Please fix the issues above.")
        print("   The application may not work correctly until all tests pass.")

    print()
    print("=" * 70)


if __name__ == "__main__":
    main()
