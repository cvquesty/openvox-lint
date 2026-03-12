# openvox-lint

[![Gem Version](https://img.shields.io/gem/v/openvox-lint)](https://rubygems.org/gems/openvox-lint)
[![Gem Downloads](https://img.shields.io/gem/dt/openvox-lint)](https://rubygems.org/gems/openvox-lint)
![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%202.5-red)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Checks](https://img.shields.io/badge/built--in%20checks-37-brightgreen)
![Status](https://img.shields.io/badge/status-stable-brightgreen)

**A style-guide linter for OpenVox and Puppet manifests.**

openvox-lint checks your `.pp` manifest files against the [Puppet Style Guide](https://puppet.com/docs/puppet/latest/style_guide.html) and catches common errors, deprecated patterns, legacy facts, strict-mode violations, and Puppet 8+ / OpenVox 8.x language issues.

Fully compatible with:
- **OpenVox 8.x** (the community-maintained open-source fork of Puppet)
- **Puppet 8.x**
- Legacy Puppet 7.x manifests (with deprecation warnings)

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Enabling and Disabling Checks](#enabling-and-disabling-checks)
- [Built-in Checks (37)](#built-in-checks)
- [Configuration](#configuration)
- [Output Formats](#output-formats)
- [Integration](#integration)
- [Writing Custom Checks](#writing-custom-checks)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Development](#development)
- [License](#license)

---

## Prerequisites

| Requirement | Version | Notes |
|------------|---------|-------|
| **Ruby** | ≥ 2.5.0 | Required; check with `ruby --version`. Works with macOS system Ruby (2.6), RHEL 8 system Ruby (2.5), and all newer versions. |
| **RubyGems** | ≥ 2.0 | Included with Ruby 2.5+ |
| **Bundler** | ≥ 2.0 | `gem install bundler` if not present |
| **OpenVox or Puppet** | 8.x | Optional; openvox-lint works standalone without an agent |
| **Git** | ≥ 2.0 | For installation from source |

### Optional Prerequisites

| Tool | Purpose |
|------|---------|
| `puppet` or `openvox` binary | For `puppet parser validate` syntax checking |
| `metadata-json-lint` gem | For linting module `metadata.json` files |
| `vim-openvox` Vim plugin | For IDE integration (async linting in Vim) |
| `rake` gem | For running tests during development |
| `rspec` gem | For running the test suite |

### Supported Platforms

- macOS (Apple Silicon and Intel)
- Linux (x86_64, aarch64)
- Windows (via Ruby for Windows)

---

## Installation

### From RubyGems (recommended)

```bash
gem install openvox-lint
```

### From Source

```bash
git clone https://github.com/cvquesty/openvox-lint.git
cd openvox-lint
gem build openvox-lint.gemspec
gem install openvox-lint-*.gem
```

### Via Bundler

Add to your `Gemfile`:

```ruby
gem 'openvox-lint'
```

Then run:

```bash
bundle install
```

---

## Quick Start

```bash
# Lint a single file
openvox-lint manifests/init.pp

# Lint all .pp files in a directory tree
openvox-lint manifests/

# Lint current directory
openvox-lint .

# List all available checks
openvox-lint --list-checks

# JSON output for CI
openvox-lint -f json manifests/
```

---

## Usage

```
Usage: openvox-lint [options] [file|directory ...]

Options:
    --version                    Display version
    -f, --format FORMAT          Output format: text, json, csv, github, codeclimate
    --log-format FORMAT          Custom log format string
    --fix                        Automatically fix problems where possible
    --fail-on-warnings           Exit with error code on warnings
    --no-filename                Suppress filename in output
    --no-column                  Suppress column number in output
    --relative                   Display relative file paths
    --only-checks CHECKS         Comma-separated list of checks to run
    --ignore-paths PATHS         Comma-separated list of glob patterns to ignore
    --list-checks                List all available checks
    -c, --config FILE            Path to configuration file
    --no-<check_name>-check      Disable a specific check
```

### Examples

```bash
# Disable specific checks
openvox-lint --no-line_length-check --no-arrow_alignment-check .

# Run only specific checks
openvox-lint --only-checks legacy_facts,hiera3_function,top_scope_facts .

# Custom log format (compatible with puppet-lint)
openvox-lint --log-format '%{path}:%{line}:%{column}:%{KIND}:%{check}:%{message}' .

# GitHub Actions annotations
openvox-lint -f github manifests/

# Fail CI on warnings too
openvox-lint --fail-on-warnings manifests/
```

---

## Enabling and Disabling Checks

openvox-lint gives you fine-grained control over which checks run. This is useful when your project has intentional style deviations, or when you want to focus on specific issues.

### Disabling Individual Checks

Use `--no-<check_name>-check` on the command line to turn off a specific check:

```bash
# Disable the line length check
openvox-lint --no-line_length-check manifests/

# Disable multiple checks at once
openvox-lint --no-line_length-check --no-arrow_alignment-check --no-strict_indent-check manifests/
```

### Running Only Specific Checks

Use `--only-checks` to run *only* the checks you specify (everything else is skipped):

```bash
# Only check for legacy facts and deprecated Hiera 3 functions
openvox-lint --only-checks legacy_facts,hiera3_function,top_scope_facts manifests/

# Only check for errors (skip all warnings)
openvox-lint --only-checks hiera3_function,import_statement,duplicate_params manifests/
```

### Disabling Checks in a Configuration File

Instead of passing flags every time, create a `.openvox-lint.rc` file in your project root:

```
# .openvox-lint.rc
# Each line is a command-line argument

# Disable checks that don't apply to our project
--no-line_length-check
--no-strict_indent-check
--no-documentation-check

# Ignore vendored code
--ignore-paths vendor/**/*.pp,pkg/**/*.pp
```

openvox-lint looks for this file automatically in the current directory and in `~/.openvox-lint.rc`.

### Suppressing Checks on Specific Lines

Use inline comments to suppress a check for a specific block of code:

```puppet
# Suppress a check for the next block
# lint:ignore:line_length
$very_long_variable = 'this line intentionally exceeds the limit because it is a configuration string'
# lint:endignore

# Suppress on a single line
class myclass { # lint:ignore:documentation
  # ...
}
```

### Listing All Available Checks

To see every check that openvox-lint can run:

```bash
openvox-lint --list-checks
```

This shows the check name, severity (warning or error), and description for all 37 built-in checks.

---

## Built-in Checks

openvox-lint ships with **37 built-in checks** organized into categories:

### Whitespace & Formatting (5 checks)

| Check | Severity | Description |
|-------|----------|-------------|
| `trailing_whitespace` | warning | No trailing whitespace at end of lines |
| `hard_tabs` | warning | Use 2-space soft tabs, not literal tabs |
| `line_length` | warning | Lines should not exceed 140 characters |
| `space_before_arrow` | warning | Only the longest key in an aligned block should have one space before `=>` |
| `strict_indent` | warning | Indentation must use 2-space increments |

### Arrow Alignment (1 check)

| Check | Severity | Description |
|-------|----------|-------------|
| `arrow_alignment` | warning | `=>` arrows should align within resource bodies |

### Quoting & Strings (5 checks)

| Check | Severity | Description |
|-------|----------|-------------|
| `double_quoted_strings` | warning | Use single quotes for strings without interpolation, escapes, or nested quotes |
| `only_variable_string` | warning | Don't quote strings containing only a variable |
| `single_quote_string_with_variables` | warning | Use double quotes for strings with variables |
| `variables_not_enclosed` | warning | Variables in strings must use `${var}` braces |
| `quoted_booleans` | warning | Don't quote boolean values `true`/`false` |

### Variables (2 checks)

| Check | Severity | Description |
|-------|----------|-------------|
| `variable_is_lowercase` | warning | All variables must be lowercase |
| `variable_contains_dash` | warning | Variables must not contain dashes |

### Resources (7 checks)

| Check | Severity | Description |
|-------|----------|-------------|
| `ensure_first_param` | warning | `ensure` must be the first attribute |
| `ensure_not_symlink_target` | warning | Use `ensure => link` with `target` |
| `file_mode` | warning | File modes as 4-digit quoted octal or symbolic |
| `unquoted_file_mode` | warning | File modes must be quoted strings |
| `unquoted_resource_title` | warning | Resource titles must be quoted |
| `duplicate_params` | error | No duplicate parameters in resources |
| `trailing_comma` | warning | Trailing comma after last attribute |

### Classes & Defines (5 checks)

| Check | Severity | Description |
|-------|----------|-------------|
| `documentation` | warning | Classes/defines must have preceding documentation |
| `nested_classes_or_defines` | warning | No nesting of classes or defines |
| `parameter_order` | warning | Params without defaults before params with defaults |
| `class_inherits_params` | warning | Avoid class inheritance; use composition |
| `inherits_across_namespaces` | warning | No inheritance across module namespaces |

### Conditionals (2 checks)

| Check | Severity | Description |
|-------|----------|-------------|
| `case_without_default` | warning | Case statements must have a `default` case |
| `selector_inside_resource` | warning | Don't use selectors inside resource bodies |

### References & Syntax (3 checks)

| Check | Severity | Description |
|-------|----------|-------------|
| `leading_zero` | warning | No leading zeros in numbers (except file modes) |
| `resource_reference_without_title_capital` | warning | Capitalise resource reference types |
| `autoloader_layout` | warning | Class/define name must match file path |

### Comments (1 check)

| Check | Severity | Description |
|-------|----------|-------------|
| `star_comments` | warning | Use `#` comments, not `/* */` |

### URLs (1 check)

| Check | Severity | Description |
|-------|----------|-------------|
| `puppet_url_without_modules` | warning | `puppet:///` URLs must include `/modules/` |

### Nodes (1 check)

| Check | Severity | Description |
|-------|----------|-------------|
| `node_name_unquoted` | warning | Node names must be quoted strings |

### Puppet 8 / OpenVox 8 Compatibility (4 checks) ⭐ NEW

| Check | Severity | Description |
|-------|----------|-------------|
| `legacy_facts` | warning | Legacy facts removed in Puppet 8; use `$facts['...']` |
| `top_scope_facts` | warning | `$::fact` references; use `$facts['fact']` |
| `hiera3_function` | **error** | Deprecated Hiera 3 functions removed; use Hiera 5 `lookup()` |
| `import_statement` | **error** | `import` removed in Puppet 4+ |

---

## Configuration

### RC File

Create `.openvox-lint.rc` in your project root or `~/.openvox-lint.rc`:

```
# Disable specific checks
--no-line_length-check
--no-strict_indent-check

# Only run specific checks
# --only-checks legacy_facts,hiera3_function

# Fail on warnings in CI
--fail-on-warnings

# Ignore paths
--ignore-paths vendor/**/*.pp,pkg/**/*.pp
```

### Inline Ignore Comments

Suppress checks on specific lines:

```puppet
# lint:ignore:line_length
$very_long_variable_name = 'a very long value that exceeds the line length limit because it is a very descriptive configuration string'
# lint:endignore

class foo { # lint:ignore:documentation
}
```

---

## Output Formats

### Text (default)

```
manifests/init.pp:5:15: WARNING: unquoted_file_mode: unquoted file mode
manifests/init.pp:9:3: ERROR: hiera3_function: deprecated Hiera 3 function 'hiera()' — use Hiera 5 lookup() instead
```

### JSON (`-f json`)

```json
[
  {
    "path": "manifests/init.pp",
    "line": 5,
    "column": 15,
    "kind": "warning",
    "check": "unquoted_file_mode",
    "message": "unquoted file mode"
  }
]
```

### GitHub Actions (`-f github`)

```
::warning file=manifests/init.pp,line=5,col=15::unquoted_file_mode: unquoted file mode
```

### CSV (`-f csv`)

```
path,line,column,kind,check,message
manifests/init.pp,5,15,warning,unquoted_file_mode,"unquoted file mode"
```

### Code Climate (`-f codeclimate`)

Standard Code Climate JSON format for quality dashboards.

### Custom (`--log-format`)

```bash
openvox-lint --log-format '%{path}:%{line}:%{column}:%{KIND}:%{check}:%{message}' .
```

Available placeholders: `%{path}`, `%{line}`, `%{column}`, `%{KIND}`, `%{kind}`, `%{check}`, `%{message}`

---

## Integration

### vim-openvox

openvox-lint is the default backend for the [vim-openvox](https://github.com/cvquesty/vim-openvox) Vim plugin. Set in `.vimrc`:

```vim
let g:openvox_lint_command = 'openvox-lint'
```

### GitHub Actions

```yaml
name: Lint
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
      - run: gem install openvox-lint
      - run: openvox-lint --fail-on-warnings -f github manifests/
```

### Rake Integration

```ruby
require 'openvox-lint'

task :lint do
  linter = OpenvoxLint::Linter.new
  linter.run('manifests/')
  OpenvoxLint::Report.new(OpenvoxLint.configuration).format(linter.problems)
  exit linter.exit_code
end
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.pp$')
[ -z "$files" ] && exit 0
openvox-lint --fail-on-warnings $files
```

---

## Writing Custom Checks

Create a Ruby file with a check plugin:

```ruby
# lib/openvox-lint/plugins/checks/my_custom_check.rb
OpenvoxLint.new_check(:my_custom_check) do
  def check
    tokens.each do |tok|
      if tok.type == :NAME && tok.value == 'something_bad'
        notify :warning,
          message: 'found something bad',
          line: tok.line,
          column: tok.column
      end
    end
  end
end
```

Place in `lib/openvox-lint/plugins/checks/` and it will be auto-loaded.

---

## Updating

### From RubyGems

```bash
# Update to the latest version
gem update openvox-lint

# Check the installed version
openvox-lint --version
```

### From Bundler

Update the version constraint in your `Gemfile` if needed, then:

```bash
bundle update openvox-lint
```

### From Source

```bash
cd openvox-lint
git pull origin main
gem build openvox-lint.gemspec
gem install openvox-lint-*.gem
```

---

## Uninstalling

### Remove the Gem

```bash
gem uninstall openvox-lint
```

If you have multiple versions installed, it will ask which one to remove. To remove all versions:

```bash
gem uninstall openvox-lint --all
```

### Remove Configuration Files

These are optional — openvox-lint does not leave system-wide files, but you may have created project or user configuration:

```bash
# Remove per-user config (if you created one)
rm -f ~/.openvox-lint.rc

# Remove per-project config (in each project that has one)
rm -f /path/to/project/.openvox-lint.rc
```

### Remove from Bundler

Remove the `gem 'openvox-lint'` line from your `Gemfile`, then:

```bash
bundle install
```

---

## Development

```bash
git clone https://github.com/cvquesty/openvox-lint.git
cd openvox-lint
bundle install
bundle exec rake spec
```

### Project Structure

```
openvox-lint/
├── bin/
│   └── openvox-lint              # CLI executable
├── lib/
│   ├── openvox-lint.rb           # Main entry point
│   └── openvox-lint/
│       ├── version.rb            # Version constant
│       ├── configuration.rb      # Configuration management
│       ├── token.rb              # Token data structure
│       ├── lexer.rb              # Puppet/OpenVox lexer/tokenizer
│       ├── check_plugin.rb       # Base class for checks
│       ├── checks.rb             # Check runner/orchestrator
│       ├── report.rb             # Output formatters
│       ├── linter.rb             # File-level orchestrator
│       ├── cli.rb                # Command-line interface
│       └── plugins/
│           └── checks/           # 38 built-in check plugins
│               ├── trailing_whitespace.rb
│               ├── legacy_facts.rb
│               ├── hiera3_function.rb
│               └── ...
├── spec/                         # RSpec test suite
├── openvox-lint.gemspec
├── Gemfile
├── Rakefile
├── LICENSE                       # Apache 2.0
├── README.md
├── CHANGELOG.md
└── DOCUMENTATION.md
```

---

## Comparison with puppet-lint

| Feature | puppet-lint 5.x | openvox-lint 1.0 |
|---------|-----------------|------------------|
| Ruby requirement | ≥ 3.1 | ≥ 2.5 (RHEL 8, macOS, all modern platforms) |
| Runtime dependencies | None | None |
| Built-in checks | ~25 | 37 |
| Legacy facts detection | Via plugin | Built-in |
| Top-scope facts detection | Via plugin | Built-in |
| Deprecated Hiera 3 function detection | No | Built-in (error) |
| Import statement detection | No | Built-in (error) |
| Strict indent check | Via plugin | Built-in |
| GitHub Actions output | No | Built-in (`-f github`) |
| Code Climate output | No | Built-in (`-f codeclimate`) |
| CSV output | No | Built-in (`-f csv`) |
| Custom log format | Yes | Yes (compatible) |
| OpenVox awareness | No | Yes |
| Plugin system | Yes | Yes (compatible) |
| `--fix` support | Yes | Yes |
| vim-openvox integration | No | Native |

---

## Links

- **RubyGems**: [rubygems.org/gems/openvox-lint](https://rubygems.org/gems/openvox-lint)
- **GitHub**: [github.com/cvquesty/openvox-lint](https://github.com/cvquesty/openvox-lint)
- **Issues**: [github.com/cvquesty/openvox-lint/issues](https://github.com/cvquesty/openvox-lint/issues)

## License

Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

---

## Author

Jerald Sheets ([@cvquesty](https://github.com/cvquesty))
