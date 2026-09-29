# Contributing to Kafka DR Demo

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/your-username/kafka-dr-confluent-aws.git
   cd kafka-dr-confluent-aws
   ```

3. Install development dependencies:
   ```bash
   # Python dependencies
   cd apps/producer && pip install -r requirements.txt
   cd ../consumer && pip install -r requirements.txt
   
   # Terraform
   cd ../../terraform && terraform init
   ```

## Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the code style guidelines below

3. Run tests and validation:
   ```bash
   make validate
   make test
   ```

4. Commit your changes with a descriptive message:
   ```bash
   git commit -m "Add feature: description of your changes"
   ```

5. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

6. Open a Pull Request against the main repository

## Code Style Guidelines

### Python
- Follow PEP 8 style guide
- Use type hints where appropriate
- Maximum line length: 100 characters
- Use descriptive variable names
- Add docstrings for functions and classes

### Terraform
- Use consistent formatting (run `terraform fmt`)
- Add descriptions for all variables
- Tag all resources appropriately
- Use modules for reusable components

### Shell Scripts
- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote all variables
- Add comments for complex logic

## Testing

### Python Tests
```bash
cd apps/producer
pytest tests/ -v --cov=producer

cd ../consumer
pytest tests/ -v --cov=consumer
```

### Terraform Validation
```bash
cd terraform
terraform validate
terraform fmt -check -recursive
```

## Pull Request Guidelines

- **Title**: Use a clear, descriptive title
- **Description**: Explain what changes you made and why
- **Tests**: Include tests for new functionality
- **Documentation**: Update README.md if needed
- **Breaking Changes**: Clearly mark any breaking changes
- **Screenshots**: Include screenshots for UI changes

## Reporting Issues

When reporting issues, please include:
- A clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your environment (Terraform version, Python version, etc.)
- Relevant logs or error messages

## Code Review Process

1. All PRs require at least one approval
2. CI checks must pass
3. Maintainers will review within 1-2 business days
4. Address review feedback promptly
5. Once approved, a maintainer will merge your PR

## Questions?

Feel free to open an issue with the `question` label for any clarifications.

Thank you for contributing! 🎉
