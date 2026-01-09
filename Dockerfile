# Use an official Python runtime as a parent image
FROM python:3.14-slim

# Set the working directory in the container
WORKDIR /app

# Install system dependencies for Tesseract OCR and PDF processing
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    libtesseract-dev \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Install the package in editable mode
RUN pip install -e .

# Expose the port the app runs on
EXPOSE 8000

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV SOURCE_FOLDER=/app/receipts/source
ENV OUTPUT_BASE_FOLDER=/app/receipts/sorted

# Create default directories
RUN mkdir -p /app/receipts/source /app/receipts/sorted

# Command to run the web application
CMD ["python", "run_web.py"]
