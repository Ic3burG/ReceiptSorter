"""
PDF Processor Module
Handles PDF reading, text extraction, and OCR fallback
"""

import pdfplumber
import pytesseract
from PIL import Image
import io
import os
import logging
from typing import Optional
from . import config

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DocumentProcessor:
    """Process PDF and image files and extract text content"""

    def __init__(self):
        """Initialize processor with OCR configuration"""
        if config.TESSERACT_CMD:
            pytesseract.pytesseract.tesseract_cmd = config.TESSERACT_CMD

    def extract_text(self, file_path: str) -> Optional[str]:
        """
        Extract text from file (PDF or Image)

        Args:
            file_path: Path to the file

        Returns:
            Extracted text or None if extraction fails
        """
        ext = os.path.splitext(file_path)[1].lower()
        
        if ext == '.pdf':
            return self._extract_from_pdf(file_path)
        elif ext in ['.jpg', '.jpeg', '.png', '.tiff', '.bmp']:
            return self._extract_from_image(file_path)
        else:
            logger.warning(f"Unsupported file format: {ext}")
            return None

    def _extract_from_pdf(self, pdf_path: str) -> Optional[str]:
        """Extract text from PDF using native text layer or OCR fallback"""
        try:
            # Try native text extraction first
            text = self._extract_native_text(pdf_path)

            # If no text found, try OCR
            if not text or len(text.strip()) < 10:
                logger.info(f"Native text extraction yielded minimal text, trying OCR for {pdf_path}")
                text = self._extract_ocr_text(pdf_path)

            return text
        except Exception as e:
            logger.error(f"Error processing PDF {pdf_path}: {str(e)}")
            return None

    def _extract_from_image(self, image_path: str) -> Optional[str]:
        """Extract text from image using OCR"""
        try:
            img = Image.open(image_path)
            text = pytesseract.image_to_string(img)
            return text
        except Exception as e:
            logger.error(f"Error processing image {image_path}: {str(e)}")
            return None

    def _extract_native_text(self, pdf_path: str) -> Optional[str]:
        """
        Extract text from PDF using native text layer

        Args:
            pdf_path: Path to the PDF file

        Returns:
            Extracted text or empty string
        """
        try:
            with pdfplumber.open(pdf_path) as pdf:
                text_parts = []
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text_parts.append(page_text)

                return "\n".join(text_parts)
        except Exception as e:
            logger.warning(f"Native text extraction failed for {pdf_path}: {str(e)}")
            return ""

    def _extract_ocr_text(self, pdf_path: str) -> Optional[str]:
        """
        Extract text from PDF using OCR (for scanned documents)

        Args:
            pdf_path: Path to the PDF file

        Returns:
            OCR extracted text or empty string
        """
        try:
            with pdfplumber.open(pdf_path) as pdf:
                text_parts = []
                for page_num, page in enumerate(pdf.pages):
                    # Convert page to image
                    img = page.to_image(resolution=300)
                    pil_image = img.original

                    # Perform OCR
                    page_text = pytesseract.image_to_string(pil_image)
                    if page_text:
                        text_parts.append(page_text)

                    logger.info(f"OCR processed page {page_num + 1} of {pdf_path}")

                return "\n".join(text_parts)
        except Exception as e:
            logger.error(f"OCR extraction failed for {pdf_path}: {str(e)}")
            return ""

    def validate_file(self, file_path: str) -> bool:
        """
        Check if file is valid and readable

        Args:
            file_path: Path to the file

        Returns:
            True if file is valid, False otherwise
        """
        try:
            ext = os.path.splitext(file_path)[1].lower()
            if ext == '.pdf':
                with pdfplumber.open(file_path) as pdf:
                    return len(pdf.pages) > 0
            elif ext in ['.jpg', '.jpeg', '.png', '.tiff', '.bmp']:
                with Image.open(file_path) as img:
                    img.verify()
                    return True
            return False
        except Exception as e:
            logger.error(f"File validation failed for {file_path}: {str(e)}")
            return False
