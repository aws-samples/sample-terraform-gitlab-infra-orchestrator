# Contributing Guidelines

We welcome contributions to the Terraform Orchestration and Automation Framework! This document provides guidelines for contributing to this project.

## Code of Conduct

This project adheres to the Amazon Open Source Code of Conduct. By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Issues

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Environment details (Terraform version, AWS provider version, etc.)
- Relevant logs or error messages

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- A clear and descriptive title
- A detailed description of the proposed enhancement
- Use cases that would benefit from this enhancement
- Any relevant examples or mockups

### Pull Requests

1. **Fork the repository** and create your branch from `dev`
2. **Follow the development workflow**:
   - Always work in the `dev` branch
   - Test your changes thoroughly
   - Ensure all existing tests pass
3. **Code standards**:
   - Follow Terraform best practices
   - Use consistent naming conventions
   - Add comments for complex logic
   - Update documentation as needed
4. **Commit messages**:
   - Use conventional commit format: `type(scope): description`
   - Examples: `feat(alb): add SSL certificate support`, `fix(ec2): resolve security group conflicts`
5. **Testing**:
   - Test your changes in a development environment
   - Validate Terraform syntax with `terraform validate`
   - Run security scans if applicable
6. **Documentation**:
   - Update README.md if needed
   - Update relevant documentation files
   - Add or update examples

### Development Workflow

```bash
# 1. Fork and clone the repository
git clone https://github.com/your-username/aws-terraform-gitlab-infra-orchestrator.git
cd aws-terraform-gitlab-infra-orchestrator

# 2. Create a feature branch from dev
git checkout dev
git checkout -b feature/your-feature-name

# 3. Make your changes and test
# ... make changes ...
terraform validate
terraform plan -var-file=tfvars/dev-terraform.tfvars

# 4. Commit your changes
git add .
git commit -m "feat(component): add new feature"

# 5. Push to your fork and create a pull request
git push origin feature/your-feature-name
```

## Development Guidelines

### Terraform Code Standards

- Use consistent indentation (2 spaces)
- Follow Terraform naming conventions
- Use descriptive variable names
- Add validation rules for variables where appropriate
- Include descriptions for all variables and outputs
- Use locals for complex expressions
- Tag all resources consistently

### Security Considerations

- Never commit sensitive information (credentials, keys, etc.)
- Use placeholder values in examples
- Follow AWS security best practices
- Implement least privilege access
- Enable encryption where applicable

### Documentation Standards

- Keep documentation up to date
- Use clear and concise language
- Include practical examples
- Document any prerequisites
- Explain complex configurations

## Testing

### Local Testing

Before submitting a pull request:

1. **Validate Terraform syntax**:
   ```bash
   terraform validate
   ```

2. **Check formatting**:
   ```bash
   terraform fmt -check
   ```

3. **Run security scans** (if available):
   ```bash
   tfsec .
   ```

4. **Test in development environment**:
   ```bash
   terraform plan -var-file=tfvars/dev-terraform.tfvars
   ```

### Integration Testing

- Test the complete deployment workflow
- Verify cross-account role assumptions work
- Validate state management functionality
- Test promotion workflow between environments

## Review Process

1. **Automated checks**: All pull requests must pass automated checks
2. **Code review**: At least one maintainer must review and approve
3. **Testing**: Changes must be tested in a development environment
4. **Documentation**: Documentation must be updated if applicable

## Release Process

This project follows semantic versioning (SemVer):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Getting Help

- Check the [README.md](README.md) for setup instructions
- Review [ARCHITECTURE.md](docs/ARCHITECTURE.md) for technical details
- Check [SECURITY-BEST-PRACTICES.md](docs/SECURITY-BEST-PRACTICES.md) for security guidance
- Open an issue for questions or problems

## Recognition

Contributors will be recognized in the project documentation and release notes.

Thank you for contributing to the Terraform Orchestration and Automation Framework!