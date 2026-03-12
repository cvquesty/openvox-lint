# Contributing to openvox-lint

Thank you for your interest in contributing to openvox-lint! This document
provides guidelines for contributing code, documentation, and bug reports.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Running Tests](#running-tests)
- [Submitting Changes](#submitting-changes)
- [Writing Check Plugins](#writing-check-plugins)
- [Coding Standards](#coding-standards)
- [Documentation](#documentation)
- [Releasing](#releasing)

---

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/).
Be respectful, inclusive, and constructive in all interactions.

---

## Getting Started

### Prerequisites

- Ruby ≥ 2.5.0
- Bundler ≥ 2.0
- Git

### Clone the Repository

```bash
git clone https://github.com/cvquesty/openvox-lint.git
cd openvox-lint
```

### Install Dependencies

```bash
bundle install
```

---

## Development Setup

### Project Structure

```
openvox-lint/
├── bin/
│   └── openvox-lint              # CLI entry point
├── lib/
│   ├── openvox-lint.rb           # Main module
│   └── openvox-lint/
│       ├── version.rb            # Version constant
│       ├── configuration.rb      # Configuration management
│       ├── token.rb              # Token data structure
│       ├── lexer.rb              # Manifest lexer
│       ├── check_plugin.rb       # Base check class
│       ├── checks.rb             # Check runner
│       ├── report.rb             # Output formatters
│       ├── linter.rb             # File orchestrator
│       ├── cli.rb                # CLI parser
│       └── plugins/
│           └── checks/           # Built-in check plugins
├── spec/                         # RSpec tests
├── openvox-lint.gemspec
├── Gemfile
└── Rakefile
```

### Key Classes

| Class | Purpose |
|-------|---------|
| `Lexer` | Tokenises Puppet/OpenVox manifests |
| `Token` | Represents a single lexer token |
| `CheckPlugin` | Base class for lint checks |
| `Checks` | Runs enabled checks against tokens |
| `Linter` | Orchestrates file discovery and linting |
| `Report` | Formats output in various formats |
| `Configuration` | Holds runtime configuration |
| `CLI` | Command-line interface |

---

## Running Tests

### Full Test Suite

```bash
bundle exec rake spec
```

### Single Test File

```bash
bundle exec rspec spec/unit/lexer_spec.rb
bundle exec rspec spec/unit/checks_spec.rb
```

### Run Linting Against Itself

```bash
bundle exec ruby -Ilib bin/openvox-lint spec/fixtures/
```

### RuboCop

```bash
bundle exec rubocop
```

---

## Submitting Changes

### 1. Fork and Branch

```bash
git checkout -b feature/my-new-check
```

### 2. Make Changes

- Write code following our [coding standards](#coding-standards)
- Add tests for new functionality
- Update documentation as needed

### 3. Test

```bash
bundle exec rake spec
bundle exec rubocop
```

### 4. Commit

Use [conventional commits](https://www.conventionalcommits.org/):

```bash
git commit -m "feat: add new_check_name check for XYZ pattern"
git commit -m "fix: correct false positive in arrow_alignment"
git commit -m "docs: add examples for legacy_facts check"
```

Commit types:
- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `test:` — Test only
- `refactor:` — Code change that neither fixes a bug nor adds a feature
- `chore:` — Maintenance tasks

### 5. Push and Open PR

```bash
git push origin feature/my-new-check
```

Open a pull request on GitHub with:
- Clear description of changes
- Link to related issue (if any)
- Test results

---

## Writing Check Plugins

### Basic Check Structure

```ruby
# lib/openvox-lint/plugins/checks/my_check.rb
# frozen_string_literal: true

# Description of what this check detects and why it matters.
OpenvoxLint.new_check(:my_check) do
  def check
    # Implement check logic
    tokens.each do |tok|
      if bad_pattern?(tok)
        notify :warning,
          message: 'description of problem',
          line: tok.line,
          column: tok.column
      end
    end
  end

  private

  def bad_pattern?(tok)
    # Detection logic
  end
end
```

### Available Helper Methods

| Method | Description |
|--------|-------------|
| `tokens` | Array of all tokens |
| `manifest_lines` | Array of source lines |
| `semantic_tokens` | Tokens excluding whitespace/comments |
| `resource_indexes` | Array of resource body info |
| `class_indexes` | Array of class definition info |
| `defined_type_indexes` | Array of defined type info |
| `node_indexes` | Array of node definition info |
| `title_tokens` | Array of resource title tokens |
| `fullpath` | Full path to file being checked |
| `filename` | Base filename |

### Reporting Problems

```ruby
# Warning (style issue)
notify :warning,
  message: 'human-readable description',
  line: token.line,
  column: token.column

# Error (will cause runtime failure)
notify :error,
  message: 'critical problem description',
  line: token.line,
  column: token.column
```

### Adding Tests

Create tests in `spec/unit/checks_spec.rb`:

```ruby
describe ':my_check' do
  it 'detects the bad pattern' do
    problems = lint("bad_code_here", checks: %w[my_check])
    expect(problems.size).to eq(1)
    expect(problems.first[:check]).to eq(:my_check)
  end

  it 'passes good code' do
    problems = lint("good_code_here", checks: %w[my_check])
    expect(problems).to be_empty
  end
end
```

---

## Coding Standards

### Ruby Style

- Follow [Ruby Style Guide](https://rubystyle.guide/)
- Use frozen string literal pragma: `# frozen_string_literal: true`
- 2-space indentation
- Maximum line length: 100 characters
- Run `rubocop` before committing

### Naming Conventions

| Entity | Convention | Example |
|--------|------------|---------|
| Check names | `snake_case` | `:legacy_facts` |
| Class names | `PascalCase` | `CheckPlugin` |
| Methods | `snake_case` | `resource_indexes` |
| Constants | `SCREAMING_SNAKE` | `LEGACY_FACTS` |

### Check Plugin Guidelines

1. **Single Responsibility** — Each check detects one type of issue
2. **Clear Messages** — Problem messages should explain what's wrong
3. **Accurate Location** — Report the exact line and column
4. **No False Positives** — Prefer missing problems over wrong ones
5. **Documentation** — Include a comment explaining the check's purpose

### Commit Messages

- Use conventional commit format
- First line: imperative mood, ≤ 72 characters
- Body: explain why, not just what
- Reference issues: `Fixes #123`

---

## Documentation

### Code Comments

```ruby
# Brief description of what this check detects.
#
# More detailed explanation if needed, including:
# - Why this pattern is problematic
# - What the correct pattern looks like
# - Any exceptions or edge cases
OpenvoxLint.new_check(:example_check) do
  # ...
end
```

### README Updates

Update README.md when:
- Adding new checks (update check count and table)
- Adding CLI options
- Changing default behaviour

### DOCUMENTATION.md Updates

Update DOCUMENTATION.md when:
- Adding new checks (full documentation with examples)
- Changing API
- Adding new token types

### CHANGELOG.md Updates

Add an entry to CHANGELOG.md for every user-visible change:

```markdown
## [Unreleased]

### Added
- New `my_check` check that detects XYZ pattern

### Fixed
- False positive in `existing_check` when ABC

### Changed
- `some_check` now also flags DEF pattern
```

---

## Releasing

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** — Breaking changes
- **MINOR** — New features, backwards compatible
- **PATCH** — Bug fixes, backwards compatible

### Release Process (Maintainers)

1. Update `lib/openvox-lint/version.rb`
2. Update `CHANGELOG.md` with release date
3. Update check count in README.md and DOCUMENTATION.md
4. Commit: `git commit -m "chore: release v1.2.0"`
5. Tag: `git tag v1.2.0`
6. Push: `git push origin main --tags`
7. Build gem: `gem build openvox-lint.gemspec`
8. Publish: `gem push openvox-lint-1.2.0.gem`

---

## Getting Help

- **Issues**: [github.com/cvquesty/openvox-lint/issues](https://github.com/cvquesty/openvox-lint/issues)
- **Discussions**: Open an issue for questions

---

## License

By contributing, you agree that your contributions will be licensed under
the Apache License 2.0.
