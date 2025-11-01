# Contributing to Receipt Sorter

Thank you for your interest in contributing to Receipt Sorter! This document provides guidelines for contributing to the project.

## Development Setup

1. Clone the repository
2. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Install Tesseract OCR (see README.md)
5. Create `.env` file with your API key

## Code Structure

### Core Modules

- **config.py** - Configuration settings, categories, currencies
- **pdf_processor.py** - PDF text extraction and OCR
- **data_extractor.py** - Claude AI integration for data extraction
- **categorizer.py** - Claude AI integration for categorization
- **file_organizer.py** - File operations and organization
- **spreadsheet_manager.py** - Excel spreadsheet generation
- **main.py** - Application entry point and CLI

### Adding New Features

#### Adding a New Currency

1. Update `SUPPORTED_CURRENCIES` in `config.py`
2. Add currency symbol mapping in `CURRENCY_SYMBOLS`
3. Update `_get_currency_symbol()` in `spreadsheet_manager.py`

#### Adding a New Tax Category

1. Update `TAX_CATEGORIES` in `config.py`
2. The categorizer will automatically recognize new categories
3. Consider updating category descriptions in `categorizer.py`

#### Adding New Export Formats

1. Create a new method in `spreadsheet_manager.py`
2. Add export option to main application
3. Update documentation

## Code Style

- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Add docstrings to all functions and classes
- Keep functions focused and single-purpose
- Use meaningful variable names

## Testing

Before submitting changes:

1. Run the test setup:
   ```bash
   python test_setup.py
   ```

2. Test with sample receipts:
   ```bash
   python main.py --source test_receipts --output test_output
   ```

3. Verify:
   - PDFs are processed correctly
   - Data extraction is accurate
   - Categorization makes sense
   - Spreadsheets are formatted properly
   - Error handling works

## Logging

- Use the `logging` module for all debug/info/error messages
- Log levels:
  - `DEBUG` - Detailed diagnostic information
  - `INFO` - General informational messages
  - `WARNING` - Warning messages (non-critical issues)
  - `ERROR` - Error messages (serious issues)

Example:
```python
logger.info(f"Processing receipt: {filename}")
logger.warning(f"Low confidence categorization: {confidence}%")
logger.error(f"Failed to extract data: {str(e)}")
```

## Error Handling

- Always catch and log exceptions
- Provide helpful error messages to users
- Never let the application crash silently
- Use try-except blocks around I/O operations

## Documentation

- Update README.md for user-facing changes
- Update docstrings for code changes
- Add examples for new features
- Keep QUICKSTART.md concise and accurate

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push to your fork
7. Create a pull request

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code style changes (formatting, etc.)
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks

Example:
```
feat: Add support for JPY currency

- Added JPY to supported currencies
- Updated currency symbol mapping
- Added test cases for JPY receipts
```

## Feature Ideas

Here are some areas where contributions would be welcome:

### High Priority
- [ ] Duplicate receipt detection
- [ ] Currency conversion with exchange rates
- [ ] Batch processing improvements
- [ ] Better error recovery

### Medium Priority
- [ ] Web interface
- [ ] Email integration
- [ ] Cloud storage integration
- [ ] Export to accounting software formats

### Low Priority
- [ ] Receipt validation rules
- [ ] Annual reports
- [ ] Multi-language support
- [ ] Mobile app integration

## Security

- Never commit API keys or credentials
- Keep `.env` file in `.gitignore`
- Sanitize file paths to prevent directory traversal
- Validate all user inputs
- Report security issues privately

## Questions?

If you have questions about contributing:
1. Check existing documentation
2. Review existing code for examples
3. Open an issue for discussion
4. Reach out to maintainers

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and improve
- Follow community guidelines

Thank you for contributing! 🎉
