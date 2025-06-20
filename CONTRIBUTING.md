# Contributing to Smith

Thank you for your interest in contributing to Smith! We welcome contributions from everyone.

## How to Contribute

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
   ```bash
   git clone https://github.com/your-username/smith.git
   cd smith
   ```
3. **Create a branch** for your changes
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes**
5. **Run tests** to ensure everything works
   ```bash
   mix test
   ```
6. **Format your code**
   ```bash
   mix format
   ```
7. **Commit** your changes with a descriptive message
   ```bash
   git commit -am "Add some feature"
   ```
8. **Push** to your fork
   ```bash
   git push origin feature/your-feature-name
   ```
9. Open a **Pull Request**

## Development Setup

1. Install Elixir (1.14 or later) and Erlang/OTP 25 or later
2. Install dependencies:
   ```bash
   mix deps.get
   ```
3. Run tests:
   ```bash
   mix test
   ```

## Code Style

- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Run `mix format` before committing
- Write tests for new functionality
- Document public functions with `@moduledoc` and `@doc`

## Reporting Issues

When reporting issues, please include:

- The version of Elixir and Erlang you're using
- Steps to reproduce the issue
- Expected vs. actual behavior
- Any relevant error messages

## Pull Request Guidelines

- Keep PRs focused on a single feature or bug fix
- Update documentation as needed
- Ensure all tests pass
- Reference any related issues
- Follow the existing code style

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.
