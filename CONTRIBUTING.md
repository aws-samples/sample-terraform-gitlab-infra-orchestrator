# Contributing to the Terraform Orchestration Framework

Thanks for wanting to contribute! We built this framework because we were tired of manually deploying infrastructure, and we're always looking for ways to make it better.

## Before You Start

### Code of Conduct

Be nice to each other. That's pretty much it. We're all trying to solve the same problems here.

### What We're Looking For

- Bug fixes (especially the annoying ones)
- New features that make deployments easier
- Better documentation (we know ours isn't perfect)
- Examples for different AWS services
- Performance improvements

### What We're Not Looking For

- Breaking changes without a really good reason
- Features that only work for one specific use case
- Overly complex solutions to simple problems

## How to Contribute

### Reporting Bugs

Before you create a bug report, check if someone else already reported it. If not, include:

- What you were trying to do
- What you expected to happen
- What actually happened
- Your Terraform version, AWS provider version, etc.
- Any error messages (the full error, not just the last line)

**Pro tip**: If you can reproduce the bug in a dev environment, that makes it much easier for us to fix.

### Suggesting Features

We love feature requests! Tell us:
- What problem you're trying to solve
- How you think it should work
- Why this would be useful for other people (not just you)

### Making Changes

Here's our workflow:

1. **Fork the repo** and create a branch from `dev` (not `main`)
2. **Make your changes** - keep them focused and small if possible
3. **Test everything** - seriously, test it thoroughly
4. **Write good commit messages** - we use conventional commits
5. **Create a pull request** - explain what you changed and why

### Development Workflow

```bash
# 1. Fork and clone
git clone https://github.com/your-username/terraform-orchestration-framework.git
cd terraform-orchestration-framework

# 2. Create a feature branch from dev
git checkout dev
git checkout -b feature/your-awesome-feature

# 3. Make your changes
# ... edit files ...

# 4. Test your changes
terraform validate
terraform fmt -check
terraform plan -var-file=tfvars/dev-terraform.tfvars

# 5. Commit with a good message
git add .
git commit -m "feat(alb): add support for SSL certificates"

# 6. Push and create a PR
git push origin feature/your-awesome-feature
```

## Code Standards

### Terraform Code

- Use 2 spaces for indentation (not tabs)
- Follow Terraform naming conventions
- Add descriptions to all variables and outputs
- Use locals for complex expressions
- Tag all resources consistently

**Good example**:
```hcl
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.small"
  
  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Instance type must be from the t3 family."
  }
}
```

**Bad example**:
```hcl
variable "instance_type" {
  type = string
  default = "t3.small"
}
```

### Documentation

- Write like you're explaining to a colleague
- Use examples for complex concepts
- Keep it up to date when you change code
- Don't assume everyone knows AWS inside and out

### Commit Messages

We use conventional commits:
- `feat(scope): description` - new features
- `fix(scope): description` - bug fixes
- `docs(scope): description` - documentation changes
- `refactor(scope): description` - code refactoring

**Good examples**:
- `feat(alb): add support for SSL certificates`
- `fix(ec2): resolve security group rule conflicts`
- `docs(readme): update setup instructions`

**Bad examples**:
- `update stuff`
- `fix bug`
- `changes`

## Testing

### What to Test

Before submitting a PR:

1. **Terraform syntax**: `terraform validate`
2. **Formatting**: `terraform fmt -check`
3. **Security**: Run `tfsec .` if you have it installed
4. **Actual deployment**: Test in a dev environment

### Testing in Development

Always test your changes in a real AWS environment:

```bash
# Plan your changes
terraform plan -var-file=tfvars/dev-terraform.tfvars

# If the plan looks good, apply it
terraform apply -var-file=tfvars/dev-terraform.tfvars

# Test that everything works
# ... check your application, run health checks, etc. ...

# Clean up when done
terraform destroy -var-file=tfvars/dev-terraform.tfvars
```

### Integration Testing

If you're adding a new feature, test the whole workflow:
1. Deploy to dev
2. Create a merge request to staging
3. Deploy to staging
4. Make sure the promotion workflow still works

## Review Process

### What We Look For

- **Does it work?** We'll test your changes in our own environment
- **Is it secure?** No hardcoded credentials, proper IAM permissions, etc.
- **Is it maintainable?** Will we be able to understand and modify this code in 6 months?
- **Does it fit?** Does this change align with the framework's goals?

### Timeline

We try to review PRs within a week, but sometimes it takes longer if we're busy with other things. Feel free to ping us if it's been a while.

## Release Process

We follow semantic versioning:
- **Major** (1.0.0 → 2.0.0): Breaking changes
- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
- **Patch** (1.0.0 → 1.0.1): Bug fixes, backward compatible

## Getting Help

### Stuck on Something?

- Check the [README.md](README.md) for setup instructions
- Look at the [Architecture Guide](docs/ARCHITECTURE.md) for technical details
- Review existing issues to see if someone else had the same problem
- Ask questions in your PR - we're happy to help

### Want to Discuss Ideas?

Open an issue before you start coding. We can help you figure out the best approach and avoid wasted effort.

## Recognition

We'll add contributors to the README and mention you in release notes. It's not much, but it's our way of saying thanks.

## Common Mistakes

### Don't Do This

- **Don't commit secrets**: No AWS keys, passwords, or other sensitive data
- **Don't break existing functionality**: Make sure your changes don't break current users
- **Don't ignore the tests**: If the tests fail, fix them or explain why they should fail
- **Don't make huge PRs**: Smaller changes are easier to review and less likely to have problems

### Do This Instead

- **Use placeholder values** in examples and documentation
- **Add tests** for new functionality
- **Update documentation** when you change behavior
- **Ask questions** if you're not sure about something

## Final Thoughts

We built this framework to make our lives easier, and we hope it does the same for you. If you have ideas for improvements, we'd love to hear them.

The best contributions are the ones that solve real problems you've encountered while using the framework. Those tend to be the most useful for everyone else too.

Thanks for contributing!