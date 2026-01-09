# CI/CD Documentation

This document provides detailed information about the Continuous Integration and Continuous Deployment (CI/CD) setup for Receipt Sorter.

## Overview

Receipt Sorter uses GitHub Actions for automated testing, building, and deployment. The CI/CD pipeline ensures code quality, runs tests, builds artifacts, and automates releases.

## Workflows

### 1. Python CI (`ci-python.yml`)

**Triggers:**

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

**Jobs:**

#### Lint & Format Check

- Runs `ruff` for linting
- Runs `black` for code formatting
- Runs `mypy` for type checking
- All checks continue on error (informational only)

#### Test Matrix

- Tests on Python 3.8, 3.9, 3.10, and 3.11
- Installs Tesseract OCR for document processing tests
- Runs pytest with coverage reporting
- Uploads coverage to Codecov (Python 3.11 only)

#### Security Scan

- Runs `bandit` for security vulnerability scanning
- Runs `safety` to check for vulnerable dependencies
- Uploads security reports as artifacts

**Status:** ✅ All checks continue on error for flexibility

---

### 2. Docker Build & Push (`ci-docker.yml`)

**Triggers:**

- Push to `main` branch
- Tags matching `v*.*.*`
- Pull requests to `main`
- Manual workflow dispatch

**Jobs:**

#### Build Docker Image

- Multi-platform builds (linux/amd64, linux/arm64)
- Uses Docker Buildx with QEMU for cross-platform support
- Caches layers for faster builds
- Publishes to GitHub Container Registry (ghcr.io)

**Image Tags:**

- `latest` - Latest build from main branch
- `main` - Latest build from main branch
- `vX.Y.Z` - Semantic version tags
- `main-<sha>` - Commit SHA tags

**Testing:**

- On PRs: Builds image and runs smoke test (curl health check)
- On main/tags: Builds and pushes to registry

---

### 3. macOS App Build (`ci-macos.yml`)

**Triggers:**

- Push to `main` affecting `macos/` directory
- Pull requests affecting `macos/` directory
- Manual workflow dispatch

**Jobs:**

#### Build Swift macOS App

- Runs on macOS-latest runner
- Uses Swift 5.9
- Caches Swift Package Manager dependencies
- Builds release configuration
- Runs Swift tests
- Creates `.app` bundle using `bundle.sh`
- Optionally creates DMG installer
- Uploads artifacts with 30-day retention

**Artifacts:**

- `Receipt-Sorter-macOS` - .app bundle
- `Receipt-Sorter-DMG` - DMG installer (if create-dmg is available)

**Note:** Currently builds unsigned apps. Code signing requires Apple Developer credentials.

---

### 4. Release (`release.yml`)

**Triggers:**

- Tags matching `v*.*.*` (e.g., `v1.0.0`, `v2.1.3`)
- Manual workflow dispatch with tag input

**Jobs:**

#### Create GitHub Release

- Generates release notes from git commits
- Creates GitHub release (draft=false)
- Marks as prerelease if version contains `alpha`, `beta`, or `rc`

#### Build Python Package

- Builds wheel and source distribution
- Uploads to GitHub release as assets

#### Build Docker Image

- Builds and pushes Docker image with version tag
- Tags as `latest` and version number

#### Build macOS App

- Builds macOS .app bundle
- Creates ZIP archive
- Uploads to GitHub release

**Release Assets:**

- Python wheel (`.whl`)
- Source tarball (`.tar.gz`)
- macOS app (`.zip`)
- Docker image (published to ghcr.io)

---

### 5. Dependabot (`dependabot.yml`)

**Purpose:** Automated dependency updates

**Ecosystems:**

- Python dependencies (pip)
- GitHub Actions versions
- Docker base images

**Schedule:** Weekly on Mondays

**Configuration:**

- Groups development dependencies together
- Groups production dependencies together
- Limits to 5 open PRs per ecosystem
- Auto-labels PRs with `dependencies` and ecosystem tags

---

## Code Quality Tools

### Pre-commit Hooks

Install locally:

```bash
pip install pre-commit
pre-commit install
```

**Hooks:**

- `trailing-whitespace` - Remove trailing whitespace
- `end-of-file-fixer` - Ensure newline at end of files
- `check-yaml` - Validate YAML syntax
- `check-json` - Validate JSON syntax
- `check-toml` - Validate TOML syntax
- `check-merge-conflict` - Detect merge conflict markers
- `detect-private-key` - Prevent committing private keys
- `black` - Auto-format Python code
- `ruff` - Lint and auto-fix Python code
- `mypy` - Type checking
- `bandit` - Security scanning

### Linting Configuration

**Ruff** (`pyproject.toml`):

- Line length: 100
- Target: Python 3.8+
- Enabled rules: pycodestyle, pyflakes, isort, flake8-bugbear, comprehensions, pyupgrade
- Ignores: E501 (line too long - handled by black)

**Black** (`pyproject.toml`):

- Line length: 100
- Target versions: Python 3.8-3.11
- Excludes: venv, build, dist, macos

**MyPy** (`pyproject.toml`):

- Python version: 3.8
- Ignore missing imports: true
- Warn on unused configs: true

**Bandit** (`pyproject.toml`):

- Excludes: tests, venv, macos
- Skips: B101 (assert), B601 (paramiko)

### Testing Configuration

**Pytest** (`pytest.ini`):

- Test paths: `tests/`
- Coverage enabled by default
- Reports: terminal, HTML, XML
- Markers: `slow`, `integration`, `unit`, `requires_api`

---

## Local Development

### Running Tests

```bash
# Install dev dependencies
pip install -r requirements-dev.txt

# Run all tests
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific markers
pytest -m "not slow"
pytest -m integration
```

### Running Linters

```bash
# Lint with ruff
ruff check .

# Auto-fix with ruff
ruff check --fix .

# Format with black
black .

# Type check with mypy
mypy .

# Security scan
bandit -r .
safety check
```

### Building Docker Locally

```bash
# Build image
docker build -t receipt-sorter:local .

# Run container
docker run -p 8000:8000 --env-file .env receipt-sorter:local

# Test multi-platform build
docker buildx build --platform linux/amd64,linux/arm64 -t receipt-sorter:multi .
```

### Building macOS App Locally

```bash
cd macos

# Build with Swift Package Manager
swift build -c release

# Run tests
swift test

# Create .app bundle
./scripts/bundle.sh
```

---

## Release Process

### Creating a New Release

1. **Update version** in `pyproject.toml`:

   ```toml
   version = "1.2.3"
   ```

2. **Commit changes**:

   ```bash
   git add pyproject.toml
   git commit -m "chore: bump version to 1.2.3"
   git push origin main
   ```

3. **Create and push tag**:

   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

4. **Wait for automation**:

   - GitHub Actions will automatically trigger the release workflow
   - Monitor progress at: https://github.com/USERNAME/REPO/actions
   - Release will be created with all artifacts

5. **Verify release**:
   - Check GitHub Releases page
   - Verify Docker image: `docker pull ghcr.io/USERNAME/REPO:1.2.3`
   - Download and test artifacts

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (0.X.0): New features, backwards compatible
- **PATCH** (0.0.X): Bug fixes, backwards compatible

**Pre-release versions:**

- `v1.0.0-alpha.1` - Alpha release
- `v1.0.0-beta.1` - Beta release
- `v1.0.0-rc.1` - Release candidate

These will be marked as "pre-release" on GitHub.

---

## GitHub Secrets

No secrets are currently required for the basic CI/CD pipeline. All workflows use GitHub's built-in `GITHUB_TOKEN`.

**Optional secrets for future enhancements:**

- `DOCKERHUB_USERNAME` - Docker Hub username (if using Docker Hub instead of ghcr.io)
- `DOCKERHUB_TOKEN` - Docker Hub access token
- `PYPI_API_TOKEN` - PyPI API token for publishing packages
- `APPLE_DEVELOPER_ID` - Apple Developer certificate for code signing
- `APPLE_DEVELOPER_PASSWORD` - App-specific password for notarization
- `CODECOV_TOKEN` - Codecov token for coverage reporting (optional)

---

## Branch Protection

**Recommended settings for `main` branch:**

1. Require pull request reviews before merging
2. Require status checks to pass:
   - `Lint & Format Check`
   - `Test (Python 3.11)`
   - `Build Docker Image`
3. Require branches to be up to date before merging
4. Require conversation resolution before merging
5. Do not allow bypassing the above settings

**Configure at:** Repository Settings → Branches → Branch protection rules

---

## Monitoring and Debugging

### Viewing Workflow Runs

- Go to: https://github.com/USERNAME/REPO/actions
- Click on a workflow run to see details
- Click on a job to see logs

### Common Issues

**Tests failing in CI but passing locally:**

- Check Python version (CI tests on 3.8-3.11)
- Check environment variables
- Check file paths (CI uses Linux)

**Docker build failing:**

- Check Dockerfile syntax
- Verify base image is available
- Check for platform-specific issues

**macOS build failing:**

- Check Swift version compatibility
- Verify Package.swift dependencies
- Check bundle.sh script

### Re-running Workflows

- Click "Re-run jobs" on failed workflow
- Or push an empty commit: `git commit --allow-empty -m "trigger CI" && git push`

---

## Future Enhancements

- [ ] Add integration tests with mocked Gemini API
- [ ] Set up staging environment deployment
- [ ] Add performance benchmarking
- [ ] Implement automatic changelog generation
- [ ] Add code coverage requirements (e.g., minimum 80%)
- [ ] Set up automatic security vulnerability scanning with Snyk
- [ ] Add macOS code signing and notarization
- [ ] Publish Python package to PyPI on release
- [ ] Add iOS app build workflow
- [ ] Set up automated backups of test data
