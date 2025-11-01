"""
Data Extractor Module
Uses Claude API to extract structured data from receipt text
"""

import anthropic
import json
import logging
import re
from typing import Dict, Optional
from datetime import datetime
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataExtractor:
    """Extract structured data from receipt text using Claude API"""

    def __init__(self):
        """Initialize with Anthropic API client"""
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY not found in environment variables")

        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = "claude-3-5-sonnet-20241022"

    def extract_receipt_data(self, receipt_text: str) -> Optional[Dict]:
        """
        Extract structured data from receipt text

        Args:
            receipt_text: Raw text extracted from receipt PDF

        Returns:
            Dictionary with extracted data or None if extraction fails
        """
        try:
            # Create extraction prompt
            prompt = self._create_extraction_prompt(receipt_text)

            # Call Claude API
            message = self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )

            # Parse response
            response_text = message.content[0].text
            data = self._parse_extraction_response(response_text)

            # Validate and clean data
            if data:
                data = self._validate_data(data)
                logger.info(f"Successfully extracted data: {data.get('vendor', 'unknown')} - {data.get('amount', 'unknown')}")
                return data
            else:
                logger.warning("Failed to parse extraction response")
                return None

        except Exception as e:
            logger.error(f"Error extracting receipt data: {str(e)}")
            return None

    def _create_extraction_prompt(self, receipt_text: str) -> str:
        """
        Create prompt for Claude to extract receipt data

        Args:
            receipt_text: Raw receipt text

        Returns:
            Formatted prompt string
        """
        prompt = f"""Extract the following information from this receipt and return it as a JSON object:

Required fields:
- total_amount: The total amount paid (numeric value only, no currency symbols)
- currency: Currency code in ISO 4217 format (e.g., CAD, USD, EUR, GBP)
- date: Transaction date in YYYY-MM-DD format
- vendor: Name of the merchant/vendor
- description: Brief description of items/services purchased (1-2 sentences max)

Receipt text:
{receipt_text}

Important instructions:
1. For currency detection, look for currency symbols ($, €, £, ¥), currency codes, or infer from vendor location/language
2. If the vendor appears to be Canadian or mentions CAD, use CAD as currency
3. If you see $ without clarification and the receipt seems North American, default to CAD
4. For the date, try multiple formats and convert to YYYY-MM-DD
5. For total amount, use the final total after all taxes and fees
6. If any field cannot be determined, use "UNKNOWN" as the value

Return ONLY a valid JSON object with these exact keys: total_amount, currency, date, vendor, description
Do not include any explanation or markdown formatting, just the raw JSON."""

        return prompt

    def _parse_extraction_response(self, response_text: str) -> Optional[Dict]:
        """
        Parse JSON response from Claude

        Args:
            response_text: Raw response from Claude

        Returns:
            Parsed dictionary or None
        """
        try:
            # Try to extract JSON from response (in case there's extra text)
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)
                data = json.loads(json_str)
                return data
            else:
                logger.warning("No JSON found in response")
                return None
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON: {str(e)}")
            return None

    def _validate_data(self, data: Dict) -> Dict:
        """
        Validate and clean extracted data

        Args:
            data: Raw extracted data

        Returns:
            Cleaned and validated data
        """
        # Ensure all required fields exist
        required_fields = ['total_amount', 'currency', 'date', 'vendor', 'description']
        for field in required_fields:
            if field not in data:
                data[field] = "UNKNOWN"

        # Clean amount - remove any non-numeric characters except decimal point
        if data['total_amount'] != "UNKNOWN":
            amount_str = str(data['total_amount'])
            amount_str = re.sub(r'[^\d.]', '', amount_str)
            try:
                data['total_amount'] = float(amount_str)
            except ValueError:
                data['total_amount'] = "UNKNOWN"

        # Validate currency code
        if data['currency'] != "UNKNOWN":
            data['currency'] = data['currency'].upper()
            if len(data['currency']) != 3:
                data['currency'] = "UNKNOWN"

        # Validate date format
        if data['date'] != "UNKNOWN":
            try:
                datetime.strptime(data['date'], '%Y-%m-%d')
            except ValueError:
                # Try to parse and reformat
                data['date'] = self._parse_date(data['date'])

        # Clean vendor name
        if data['vendor'] != "UNKNOWN":
            data['vendor'] = data['vendor'].strip()[:100]  # Limit length

        # Clean description
        if data['description'] != "UNKNOWN":
            data['description'] = data['description'].strip()[:500]  # Limit length

        return data

    def _parse_date(self, date_str: str) -> str:
        """
        Try to parse date from various formats

        Args:
            date_str: Date string in unknown format

        Returns:
            Date in YYYY-MM-DD format or "UNKNOWN"
        """
        from dateutil import parser

        try:
            parsed_date = parser.parse(date_str)
            return parsed_date.strftime('%Y-%m-%d')
        except Exception:
            return "UNKNOWN"
