# Contributing to Wraft

Welcome to Wraft! We're thrilled that you're interested in contributing. By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Table of Contents

- [Quick Links](#quick-links)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Enhancements](#requesting-enhancements)
- [Style Guide](#style-guide)
- [Recognition](#recognition)
- [Getting Help](#getting-help)

## Quick Links

- Documentation: [Project Handbook](link-to-handbook) / [Roadmap](link-to-roadmap)
- Issue Tracker: [GitHub Issues](link-to-issues)
- Communication: [Forum](link-to-forum) / [Mailing List](link-to-mailing-list) / [IRC](irc-channel)

## How to Contribute

### 1. Fork the Repository

Create your own fork of the project to work on your changes without affecting the main repository.

### 2. Clone the Repository

```bash
git clone https://github.com/your-username/wraft.git
cd wraft
```

### 3. Create a Branch

We follow the Git Flow branching model:

- Features: `feature/your-feature-name`
- Bug fixes: `bugfix/issue-number-description`
- Hotfixes: `hotfix/issue-number-description`
- Releases: `release/version-number`

```bash
git checkout -b feature/your-feature-name
```

## Development Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .dev.env
   ```

2. Edit `.dev.env` with your specific configuration.

3. Source the environment variables:
   ```bash
   source .dev.env
   ```

4. Install dependencies:
   ```bash
   mix deps.get
   ```

5. Set up the database:
   ```bash
   mix ecto.setup
   ```

6. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

For more detailed instructions, please refer to our [README.md](README.md).

## Submitting Changes

1. Ensure your code adheres to our [Style Guide](#style-guide).
2. Run tests and ensure they all pass:
   ```bash
   mix test
   ```
3. Commit your changes using a descriptive commit message that follows our [commit message conventions](#commit-message-guidelines).
4. Push your branch to your fork on GitHub.
5. Submit a pull request to the `develop` branch of the main repository.

### Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types include: feat, fix, docs, style, refactor, perf, test, chore

Example:
```
feat(auth): implement JWT authentication

- Add JWT token generation
- Implement token validation middleware
- Update user model to include token field

Closes #123
```

## Reporting Bugs

Before submitting a bug report:

1. Check the [existing issues](link-to-issues) to avoid duplicates.
2. Ensure you're running the latest version of the project.

When submitting a bug report:

1. Use a clear and descriptive title.
2. Describe the exact steps to reproduce the problem.
3. Explain the behavior you observed and what you expected to see.
4. Include relevant logs, screenshots, or code samples.
5. Provide details about your environment (OS, Elixir version, etc.).

You can use our [bug report template](link-to-bug-template) to ensure you include all necessary information.

## Requesting Enhancements

Enhancement suggestions are welcome! Please submit them as GitHub issues:

1. Use a clear and descriptive title.
2. Provide a detailed description of the proposed enhancement.
3. Explain why this enhancement would be useful to most users.
4. List possible alternatives you've considered.

## Style Guide

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide). Please ensure your code adheres to these guidelines.

Use the following tools to maintain code quality:
- `mix format` to format your code
- `mix credo` for static code analysis

## Recognition

We appreciate all contributions to Wraft! Contributors will be recognized in the following ways:

- Your name will be added to our [CONTRIBUTORS.md](CONTRIBUTORS.md) file.
- Significant contributions may be mentioned in release notes.
- We use the [All Contributors](https://allcontributors.org/) specification to recognize various types of contributions.

## Getting Help

If you need help or have questions:

- Open a [GitHub Discussion](https://github.com/wraft/wraft/discussions)
- Join our [community chat](link-to-chat)
- Reach out to the maintainers: [maintainer@email.com](mailto:maintainer@email.com)

Thank you for contributing to Wraft! We look forward to collaborating with you.
