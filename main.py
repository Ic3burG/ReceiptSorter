#!/usr/bin/env python3
"""
Receipt Sorter & Categorization Application
Main entry point for processing PDF receipts

Usage:
    python main.py [--source SOURCE_FOLDER] [--output OUTPUT_FOLDER]
"""

import os
import sys
import argparse
import logging
from pathlib import Path
from typing import List, Dict
from datetime import datetime

# Import application modules
from pdf_processor import PDFProcessor
from data_extractor import DataExtractor
from categorizer import Categorizer
from file_organizer import FileOrganizer
from spreadsheet_manager import SpreadsheetManager
import config

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('receipt_sorter.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class ReceiptSorterApp:
    """Main application class for receipt processing"""

    def __init__(self, source_folder: str = None, output_folder: str = None):
        """
        Initialize application with folder paths

        Args:
            source_folder: Path to folder containing receipt PDFs
            output_folder: Path to output folder for sorted receipts
        """
        self.source_folder = source_folder or config.SOURCE_FOLDER
        self.output_folder = output_folder or config.OUTPUT_BASE_FOLDER

        # Initialize modules
        self.pdf_processor = PDFProcessor()
        self.data_extractor = DataExtractor()
        self.categorizer = Categorizer()
        self.file_organizer = FileOrganizer()
        self.spreadsheet_manager = SpreadsheetManager()

        # Statistics tracking
        self.stats = {
            'total_processed': 0,
            'successful': 0,
            'failed': 0,
            'needs_review': 0,
            'by_currency': {},
            'by_category': {}
        }

    def validate_setup(self) -> bool:
        """
        Validate that source folder exists and API key is configured

        Returns:
            True if setup is valid, False otherwise
        """
        # Check source folder
        if not os.path.exists(self.source_folder):
            logger.error(f"Source folder does not exist: {self.source_folder}")
            print(f"\n❌ Error: Source folder not found at {self.source_folder}")
            print(f"Please create the folder or specify a different path using --source")
            return False

        # Check for PDF files
        pdf_files = self.get_pdf_files()
        if not pdf_files:
            logger.warning(f"No PDF files found in {self.source_folder}")
            print(f"\n⚠️  Warning: No PDF files found in {self.source_folder}")
            print(f"Please add PDF receipts to this folder and run again.")
            return False

        # Check API key
        if not os.getenv("ANTHROPIC_API_KEY"):
            logger.error("ANTHROPIC_API_KEY not found in environment")
            print(f"\n❌ Error: ANTHROPIC_API_KEY not set")
            print(f"Please create a .env file with your API key or set it as an environment variable")
            print(f"Example: export ANTHROPIC_API_KEY='your-api-key-here'")
            return False

        print(f"✓ Found {len(pdf_files)} PDF receipt(s) to process")
        return True

    def get_pdf_files(self) -> List[str]:
        """
        Get list of PDF files in source folder

        Returns:
            List of PDF file paths
        """
        pdf_files = []
        try:
            for filename in os.listdir(self.source_folder):
                if filename.lower().endswith('.pdf'):
                    pdf_path = os.path.join(self.source_folder, filename)
                    pdf_files.append(pdf_path)
        except Exception as e:
            logger.error(f"Error listing PDF files: {str(e)}")

        return sorted(pdf_files)

    def process_receipt(self, pdf_path: str) -> bool:
        """
        Process a single receipt PDF

        Args:
            pdf_path: Path to PDF file

        Returns:
            True if successful, False otherwise
        """
        filename = os.path.basename(pdf_path)
        logger.info(f"Processing: {filename}")
        print(f"\n📄 Processing: {filename}")

        try:
            # Step 1: Validate PDF
            if not self.pdf_processor.validate_pdf(pdf_path):
                logger.error(f"Invalid or corrupted PDF: {filename}")
                print(f"   ❌ Invalid or corrupted PDF")
                self.stats['failed'] += 1
                return False

            # Step 2: Extract text from PDF
            print(f"   📖 Extracting text from PDF...")
            receipt_text = self.pdf_processor.extract_text(pdf_path)

            if not receipt_text:
                logger.error(f"Failed to extract text from {filename}")
                print(f"   ❌ Could not extract text from PDF")
                self.stats['failed'] += 1
                return False

            # Step 3: Extract structured data
            print(f"   🔍 Extracting receipt data...")
            receipt_data = self.data_extractor.extract_receipt_data(receipt_text)

            if not receipt_data:
                logger.error(f"Failed to extract data from {filename}")
                print(f"   ❌ Could not extract receipt data")
                self.stats['failed'] += 1
                return False

            # Display extracted data
            print(f"   ✓ Vendor: {receipt_data.get('vendor', 'UNKNOWN')}")
            print(f"   ✓ Date: {receipt_data.get('date', 'UNKNOWN')}")
            print(f"   ✓ Amount: {receipt_data.get('total_amount', 'UNKNOWN')} {receipt_data.get('currency', 'UNKNOWN')}")

            # Step 4: Categorize receipt
            print(f"   🏷️  Categorizing receipt...")
            categorization = self.categorizer.categorize_receipt(receipt_data)
            category = categorization.get('category', 'Other')
            confidence = categorization.get('confidence', 0)

            print(f"   ✓ Category: {category} (confidence: {confidence}%)")

            # Step 5: Determine if needs review
            needs_review = self.categorizer.needs_review(confidence)
            if needs_review:
                print(f"   ⚠️  Flagged for manual review (low confidence)")
                self.stats['needs_review'] += 1

            # Step 6: Organize file
            print(f"   📁 Organizing file...")
            organized_path = self.file_organizer.organize_receipt(
                pdf_path,
                receipt_data,
                needs_review
            )

            if not organized_path:
                logger.error(f"Failed to organize {filename}")
                print(f"   ❌ Failed to organize file")
                self.stats['failed'] += 1
                return False

            # Log operation
            self.file_organizer.log_operation(
                "PROCESS",
                pdf_path,
                organized_path,
                "SUCCESS"
            )

            # Step 7: Update spreadsheet
            print(f"   📊 Updating spreadsheet...")
            spreadsheet_success = self.spreadsheet_manager.add_receipt_entry(
                receipt_data,
                category,
                confidence,
                organized_path
            )

            if not spreadsheet_success:
                logger.warning(f"Failed to update spreadsheet for {filename}")
                print(f"   ⚠️  Could not update spreadsheet")

            # Update statistics
            self.stats['successful'] += 1
            currency = receipt_data.get('currency', 'UNKNOWN')
            self.stats['by_currency'][currency] = self.stats['by_currency'].get(currency, 0) + 1
            self.stats['by_category'][category] = self.stats['by_category'].get(category, 0) + 1

            print(f"   ✅ Successfully processed!")
            return True

        except Exception as e:
            logger.error(f"Error processing {filename}: {str(e)}")
            print(f"   ❌ Error: {str(e)}")
            self.stats['failed'] += 1
            return False

    def run(self):
        """
        Main application workflow
        """
        print("=" * 70)
        print("   RECEIPT SORTER & CATEGORIZATION APP")
        print("   Powered by Claude AI")
        print("=" * 70)

        # Validate setup
        print(f"\n🔍 Validating setup...")
        if not self.validate_setup():
            return

        # Get list of PDFs
        pdf_files = self.get_pdf_files()
        self.stats['total_processed'] = len(pdf_files)

        print(f"\n🚀 Starting processing of {len(pdf_files)} receipt(s)...")
        print(f"   Source: {self.source_folder}")
        print(f"   Output: {self.output_folder}")

        # Process each PDF
        for idx, pdf_path in enumerate(pdf_files, 1):
            print(f"\n{'─' * 70}")
            print(f"Receipt {idx} of {len(pdf_files)}")
            self.process_receipt(pdf_path)

        # Generate summary
        self.print_summary()

    def print_summary(self):
        """
        Print processing summary and statistics
        """
        print(f"\n{'=' * 70}")
        print("   PROCESSING COMPLETE")
        print(f"{'=' * 70}")

        print(f"\n📊 Summary Statistics:")
        print(f"   Total receipts processed: {self.stats['total_processed']}")
        print(f"   ✅ Successful: {self.stats['successful']}")
        print(f"   ❌ Failed: {self.stats['failed']}")
        print(f"   ⚠️  Needs review: {self.stats['needs_review']}")

        if self.stats['by_currency']:
            print(f"\n💰 By Currency:")
            for currency, count in sorted(self.stats['by_currency'].items()):
                print(f"   {currency}: {count} receipt(s)")

        if self.stats['by_category']:
            print(f"\n🏷️  By Category:")
            for category, count in sorted(self.stats['by_category'].items()):
                print(f"   {category}: {count} receipt(s)")

        print(f"\n📁 Organized receipts saved to: {self.output_folder}")

        if self.stats['needs_review'] > 0:
            print(f"\n⚠️  Please review receipts in: {config.REVIEW_FOLDER}")

        # Generate detailed summary report
        summary_report = self.spreadsheet_manager.generate_summary_report()
        if summary_report.get('currencies'):
            print(f"\n💵 Financial Summary:")
            for currency, data in summary_report['currencies'].items():
                print(f"   {currency}: {data['count']} receipts, Total: {data['total']:.2f}")

        print(f"\n{'=' * 70}\n")


def main():
    """
    Main entry point
    """
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description='Receipt Sorter & Categorization App - Automatically process and organize PDF receipts'
    )
    parser.add_argument(
        '--source',
        type=str,
        help=f'Source folder containing PDF receipts (default: {config.SOURCE_FOLDER})'
    )
    parser.add_argument(
        '--output',
        type=str,
        help=f'Output folder for sorted receipts (default: {config.OUTPUT_BASE_FOLDER})'
    )

    args = parser.parse_args()

    # Create and run application
    try:
        app = ReceiptSorterApp(
            source_folder=args.source,
            output_folder=args.output
        )
        app.run()
    except KeyboardInterrupt:
        print("\n\n⚠️  Processing interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Fatal error: {str(e)}", exc_info=True)
        print(f"\n❌ Fatal error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
