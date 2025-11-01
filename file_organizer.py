"""
File Organizer Module
Handles file operations: moving receipts to currency folders and renaming
"""

import os
import shutil
import logging
from typing import Dict
import re
import config

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class FileOrganizer:
    """Organize receipt files into currency-specific folders"""

    def __init__(self):
        """Initialize file organizer and create necessary folders"""
        self.output_base = config.OUTPUT_BASE_FOLDER
        self.ensure_base_folders()

    def ensure_base_folders(self):
        """Create base output folder structure if it doesn't exist"""
        try:
            os.makedirs(self.output_base, exist_ok=True)
            os.makedirs(config.REVIEW_FOLDER, exist_ok=True)
            logger.info(f"Ensured base folders exist at {self.output_base}")
        except Exception as e:
            logger.error(f"Error creating base folders: {str(e)}")

    def get_currency_folder(self, currency: str) -> str:
        """
        Get path to currency-specific folder

        Args:
            currency: Currency code (e.g., CAD, USD)

        Returns:
            Path to currency folder
        """
        currency = currency.upper()
        folder_path = os.path.join(self.output_base, currency)

        # Create folder if it doesn't exist
        try:
            os.makedirs(folder_path, exist_ok=True)
            logger.debug(f"Currency folder ready: {folder_path}")
        except Exception as e:
            logger.error(f"Error creating currency folder {currency}: {str(e)}")

        return folder_path

    def generate_new_filename(self, receipt_data: Dict, original_filename: str) -> str:
        """
        Generate standardized filename for receipt

        Args:
            receipt_data: Dictionary with date, vendor, amount
            original_filename: Original PDF filename

        Returns:
            New standardized filename
        """
        # Extract data with fallbacks
        date = receipt_data.get('date', 'UNKNOWN')
        vendor = receipt_data.get('vendor', 'UNKNOWN')
        amount = receipt_data.get('total_amount', 'UNKNOWN')

        # Clean vendor name for filename (remove invalid characters)
        vendor = self._sanitize_filename(vendor)

        # Format amount
        if isinstance(amount, (int, float)):
            amount_str = f"{amount:.2f}"
        else:
            amount_str = str(amount)

        # If date is unknown, try to preserve original filename
        if date == "UNKNOWN":
            date = "UNKNOWN_DATE"

        # Generate new filename
        new_name = f"{date}_{vendor}_{amount_str}.pdf"

        # If filename already exists in destination, append counter
        # (This will be handled during the actual move operation)

        return new_name

    def _sanitize_filename(self, filename: str, max_length: int = 50) -> str:
        """
        Remove invalid characters from filename

        Args:
            filename: Original filename
            max_length: Maximum length for filename component

        Returns:
            Sanitized filename
        """
        # Remove invalid characters
        sanitized = re.sub(r'[<>:"/\\|?*]', '', filename)

        # Replace spaces with underscores
        sanitized = sanitized.replace(' ', '_')

        # Remove multiple underscores
        sanitized = re.sub(r'_+', '_', sanitized)

        # Limit length
        sanitized = sanitized[:max_length]

        # Remove leading/trailing underscores
        sanitized = sanitized.strip('_')

        return sanitized if sanitized else "UNKNOWN"

    def organize_receipt(self, source_path: str, receipt_data: Dict, needs_review: bool = False) -> str:
        """
        Move and rename receipt to appropriate folder

        Args:
            source_path: Path to original PDF file
            receipt_data: Extracted receipt data
            needs_review: Whether receipt needs manual review

        Returns:
            Path to organized file, or None if operation fails
        """
        try:
            original_filename = os.path.basename(source_path)

            # Determine destination folder
            if needs_review:
                dest_folder = config.REVIEW_FOLDER
                logger.info(f"Receipt flagged for review: {original_filename}")
            else:
                currency = receipt_data.get('currency', 'UNKNOWN')
                dest_folder = self.get_currency_folder(currency)

            # Generate new filename
            new_filename = self.generate_new_filename(receipt_data, original_filename)
            dest_path = os.path.join(dest_folder, new_filename)

            # Handle duplicate filenames
            dest_path = self._get_unique_filepath(dest_path)

            # Copy file to destination (keeping original)
            shutil.copy2(source_path, dest_path)
            logger.info(f"Organized receipt: {original_filename} -> {dest_path}")

            return dest_path

        except Exception as e:
            logger.error(f"Error organizing receipt {source_path}: {str(e)}")
            return None

    def _get_unique_filepath(self, filepath: str) -> str:
        """
        Get unique filepath by appending counter if file exists

        Args:
            filepath: Desired file path

        Returns:
            Unique file path
        """
        if not os.path.exists(filepath):
            return filepath

        # Split into base and extension
        base, ext = os.path.splitext(filepath)
        counter = 1

        while os.path.exists(f"{base}_{counter}{ext}"):
            counter += 1

        return f"{base}_{counter}{ext}"

    def log_operation(self, operation: str, source: str, destination: str, status: str):
        """
        Log file operation to processing log

        Args:
            operation: Type of operation (e.g., "MOVE", "COPY")
            source: Source file path
            destination: Destination file path
            status: Operation status (e.g., "SUCCESS", "FAILED")
        """
        try:
            with open(config.LOG_FILE, 'a', encoding='utf-8') as f:
                from datetime import datetime
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                log_entry = f"[{timestamp}] {operation} | {status} | {source} -> {destination}\n"
                f.write(log_entry)
        except Exception as e:
            logger.error(f"Error writing to log file: {str(e)}")
