"""
Categorizer Module
Uses Claude API to classify receipts into Canadian tax categories
"""

import anthropic
import json
import logging
import re
from typing import Dict, Optional
import os
from dotenv import load_dotenv
from . import config

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class Categorizer:
    """Classify receipts into tax categories using Claude API"""

    def __init__(self):
        """Initialize with Anthropic API client"""
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY not found in environment variables")

        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = "claude-3-5-sonnet-20241022"
        self.categories = config.TAX_CATEGORIES

    def categorize_receipt(self, receipt_data: Dict) -> Dict[str, any]:
        """
        Categorize receipt into tax category

        Args:
            receipt_data: Dictionary with vendor, amount, description

        Returns:
            Dictionary with 'category' and 'confidence' (0-100)
        """
        try:
            # Create categorization prompt
            prompt = self._create_categorization_prompt(receipt_data)

            # Call Claude API
            message = self.client.messages.create(
                model=self.model,
                max_tokens=512,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )

            # Parse response
            response_text = message.content[0].text
            result = self._parse_categorization_response(response_text)

            if result:
                logger.info(f"Categorized as '{result['category']}' with {result['confidence']}% confidence")
                return result
            else:
                logger.warning("Failed to parse categorization response")
                return {"category": "Other", "confidence": 0}

        except Exception as e:
            logger.error(f"Error categorizing receipt: {str(e)}")
            return {"category": "Other", "confidence": 0}

    def _create_categorization_prompt(self, receipt_data: Dict) -> str:
        """
        Create prompt for Claude to categorize receipt

        Args:
            receipt_data: Receipt information

        Returns:
            Formatted prompt string
        """
        vendor = receipt_data.get('vendor', 'Unknown')
        amount = receipt_data.get('total_amount', 'Unknown')
        description = receipt_data.get('description', 'No description')

        categories_list = '\n'.join([f"- {cat}" for cat in self.categories])

        prompt = f"""Classify this receipt into one of the following Canadian tax deduction categories:

{categories_list}

Receipt details:
- Vendor: {vendor}
- Amount: {amount}
- Description: {description}

Category descriptions:
- Office Expenses: Office supplies, software, equipment, subscriptions
- Meals & Entertainment: Restaurant meals, client entertainment (50% deductible in Canada)
- Travel: Airfare, hotels, accommodation, taxis, public transit
- Vehicle Expenses: Fuel, car maintenance, parking, tolls
- Professional Services: Legal fees, accounting, consulting, professional advice
- Marketing & Advertising: Advertising costs, promotional materials, marketing services
- Utilities & Rent: Office rent, electricity, internet, phone bills
- Insurance: Business insurance premiums
- Education & Training: Courses, seminars, professional development, books
- Other: Anything that doesn't fit the above categories

Instructions:
1. Choose the MOST appropriate category from the list above
2. Provide a confidence score from 0-100 (100 = very certain, 0 = complete guess)
3. Consider the vendor name and description to make the best match
4. For meals, always use "Meals & Entertainment" even if it's a grocery store (if food-related)
5. For gas stations, use "Vehicle Expenses"
6. For online services like AWS, hosting, use "Office Expenses"

Return ONLY a valid JSON object with these exact keys: category, confidence
Example: {{"category": "Office Expenses", "confidence": 95}}
Do not include any explanation, just the raw JSON."""

        return prompt

    def _parse_categorization_response(self, response_text: str) -> Optional[Dict]:
        """
        Parse JSON response from Claude

        Args:
            response_text: Raw response from Claude

        Returns:
            Dictionary with category and confidence, or None
        """
        try:
            # Try to extract JSON from response
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)
                data = json.loads(json_str)

                # Validate category
                if data.get('category') not in self.categories:
                    logger.warning(f"Invalid category '{data.get('category')}', defaulting to 'Other'")
                    data['category'] = "Other"

                # Validate confidence
                if 'confidence' not in data:
                    data['confidence'] = 50
                else:
                    try:
                        data['confidence'] = int(data['confidence'])
                        data['confidence'] = max(0, min(100, data['confidence']))  # Clamp to 0-100
                    except ValueError:
                        data['confidence'] = 50

                return data
            else:
                logger.warning("No JSON found in categorization response")
                return None
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse categorization JSON: {str(e)}")
            return None

    def needs_review(self, confidence: int) -> bool:
        """
        Determine if categorization needs manual review

        Args:
            confidence: Confidence score (0-100)

        Returns:
            True if confidence is below threshold
        """
        return confidence < config.CATEGORIZATION_CONFIDENCE_THRESHOLD
