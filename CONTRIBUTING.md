# Contributing to Wraft

Thank you for your interest in contributing to wraft! By participating, you agree to abide by the following guidelines.

## Table of Contents

- [How to Contribute](#how-to-contribute)
- [Reporting Issues](#reporting-issues)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Code Style](#code-style)
- [Testing](#testing)
- [Getting Help](#getting-help)

## How to Contribute

### 1. Fork the Repository

Create your fork of the project to contribute without affecting the main repository.

### 2. Clone the Repository

Clone your fork to start making changes and follow the instructions given in the `README.md` file.

```bash
git clone https://github.com/wraft/wraft.git
cd wraft
```

### 3 - Running Wraft

To start your Wraft app:

**Load env variables**

Make a .dev.env file in the root directory and add the environment variables.
Refer `.env.example` for the list of variables.

Source the environment variables from the file and start the server.

```shell
$ mv .env.example .dev.env
$ source .dev.env
```

**Install dependencies with**

```shell
$ mix deps.get
```

**Setup Database**

- With seed data

```shell
$ mix ecto.setup
```

- Without seed data

```shell
$ mix ecto.create && mix ecto.migrate
```

**Start Phoenix endpoint**

- With interactive shell

```shell
$ iex -S mix phx.server
```

- Without interactive shell

```shell
$ source .dev.env && mix phx.server
```

### 3. Commit Hooks

Wraft uses `pre-commit` to standardise the code quality and style.

To install pre-commit:
Using pip:

```shell
$ pip install pre-commit
```

Using homebrew:

```
$ brew install pre-commit
```

To verify installation:

```
$ pre-commit --version
```

Now to setup pre commit for Wraft:

```
$ pre-commit install
```

### 4. Testing Wraft

```shell
$ source .env && mix test
```

### 5. Create a Branch (Git Flow)

Follow Git Flow when creating branches:

More details on Git Flow can be found [here](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow).

- **Feature branches**: Use for new features or enhancements.
  Example: `feature/my-new-feature`
- **Bugfix branches**: Use for hotfixes or bug fixes.
  Example: `bugfix/issue-123-fix`

- **Release branches**: Use for preparing releases.
  Example: `release/1.2.0`

- **Hotfix branches**: Use for urgent fixes on production.
  Example: `hotfix/urgent-issue`

Create your branch:

```bash
git checkout -b feature/my-new-feature
```

### 6. Make Changes

- Ensure your changes are meaningful and relevant.
- Follow the code style guidelines outlined below.

### 7. Push Changes

Commit your changes and push to your fork. Follow the commit message guidelines below.

#### Commit Message Guidelines

Follow [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) guidelines for writing commit messages.

Example for commit message format:
`"feat: add my new feature"`

- feat(feature): Add my new feature
- fix(bug): Fix the bug in the code
- refactor(code): Refactor the code
- docs(documentation): Update the documentation
- test(testing): Add new test cases
- style(code): Fix the code style

```bash
git add .
git commit -m "feat: add my new feature"
git push origin feature/my-new-feature
```

### 8. Submit a Pull Request (PR)

Open a PR from your feature branch to the `develop` branch (or other relevant branches if necessary) and provide a detailed description of your changes.

## Reporting Issues

Before reporting an issue, check the [existing issues](https://github.com/wraft/wraft/issues) to see if it's already been reported.

When creating a new issue, please include:

- Clear and concise title.
- Steps to reproduce the issue.
- Expected behavior.
- Actual behavior.
- Logs or screenshots, if applicable.

## Pull Request Guidelines

- Ensure all tests pass before submitting a PR.
- Write meaningful commit messages.
- Avoid unrelated changes in the same PR.
- Update documentation as necessary.
- Ensure your code follows the [Code Style](#code-style) section below.

## Code Style

For Elixir code:

- Follow [Elixir's official style guide](https://github.com/christopheradams/elixir_style_guide).
- Use `mix format` and `mix credo` to format your code.

### General Guidelines:

- Module and function names should be descriptive.
- Functions should have a single responsibility.
- Use pattern matching where applicable.

## Testing

- Ensure you write tests for any new features or bug fixes.
- Run the full test suite before submitting a pull request:

```bash
mix test
```

- Use `ExUnit` for testing and ensure your tests follow a clear and consistent structure.

## Getting Help

If you have any questions, feel free to reach out to the project maintainers or open a [GitHub Discussion](https://github.com/project-name/discussions).

---

This file now incorporates Git Flow practices and includes relevant guidance for contributors. Let me know if any further adjustments are needed!
