# openvox-lint Technical Documentation

## Overview

openvox-lint is a Ruby gem that statically analyses OpenVox / Puppet manifest
(`.pp`) files.  It tokenises each file with a purpose-built lexer, then runs
a configurable set of check plugins against the token stream.  Problems are
reported in multiple output formats suitable for humans, CI systems, and IDEs.

This document covers the architecture, every public API, every built-in check,
the lexer token types, the plugin system, and integration guidance.

**Version:** 1.3.1  
**Checks:** 37 built-in (with real --fix support for 5+ checks)  
**License:** Apache 2.0  
**Compatibility:** OpenVox 8.x, Puppet 8.x, Puppet 7.x (with deprecation warnings)

---

## Table of Contents

- [Architecture](#architecture)
- [API Reference](#api-reference)
  - [Module: OpenvoxLint](#module-openvoxlint)
  - [Class: Token](#class-openvoxlinttoken)
  - [Class: Lexer](#class-openvoxlintlexer)
  - [Class: CheckPlugin](#class-openvoxlintcheckplugin)
  - [Class: Configuration](#class-openvoxlintconfiguration)
  - [Class: Linter](#class-openvoxlintlinter)
  - [Class: Report](#class-openvoxlintreport)
- [Complete Check Reference (37 Checks)](#complete-check-reference-37-checks)
  - [Whitespace & Formatting (5)](#whitespace--formatting-5-checks)
  - [Arrow Alignment (1)](#arrow-alignment-1-check)
  - [Quoting & Strings (5)](#quoting--strings-5-checks)
  - [Variables (2)](#variables-2-checks)
  - [Resources (7)](#resources-7-checks)
  - [Classes & Defines (5)](#classes--defines-5-checks)
  - [Conditionals (2)](#conditionals-2-checks)
  - [References & Syntax (3)](#references--syntax-3-checks)
  - [Comments (1)](#comments-1-check)
  - [URLs (1)](#urls-1-check)
  - [Nodes (1)](#nodes-1-check)
  - [Puppet 8 / OpenVox 8 Compatibility (4)](#puppet-8--openvox-8-compatibility-4-checks)
- [Token Types Reference](#token-types-reference)
- [Plugin Development](#plugin-development)
- [Migration from puppet-lint](#migration-from-puppet-lint)
- [File Inventory](#file-inventory)

---

## Architecture

```
┌─────────────┐     ┌───────┐     ┌────────┐     ┌──────────┐
│  CLI / API  │────▶│ Linter │────▶│ Lexer  │────▶│  Tokens  │
│             │     │        │     │        │     │  (array)  │
└─────────────┘     └───┬────┘     └────────┘     └────┬─────┘
                        │                              │
                        │         ┌────────┐           │
                        └────────▶│ Checks │◀──────────┘
                                  │        │
                                  └───┬────┘
                                      │
                                  ┌───▼────┐
                                  │ Report │
                                  └────────┘
```

### Pipeline

1. **CLI** parses command-line arguments and loads configuration
2. **Linter** expands file arguments, reads each `.pp` file
3. **Lexer** tokenises the manifest into `Token` objects (doubly-linked list)
4. **Checks** runs each enabled check plugin against the token stream
5. **Report** formats and outputs the collected problems

### Design Principles

- **Zero runtime dependencies** — only Ruby standard library
- **Token-based analysis** — works on token stream, not AST
- **Puppet/OpenVox agnostic** — identical language support for both
- **Extensible** — plugin system for custom checks
- **CI-friendly** — multiple output formats, proper exit codes

---

## API Reference

### Module: OpenvoxLint

The top-level namespace for all openvox-lint classes.

#### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `VERSION` | `'1.3.1'` | Gem version string |

#### Class Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `.configuration` | `Configuration` | Global configuration singleton |
| `.configure { \|c\| }` | `Configuration` | Yields configuration for block-style setup |
| `.reset_configuration!` | `Configuration` | Reset configuration to defaults (called by CLI) |
| `.checks` | `Hash{Symbol => Class}` | Registry of loaded check classes |
| `.new_check(name, &block)` | `Class` | Register a new check plugin (warns on duplicates) |

#### Exceptions

| Exception | Inherits | Usage |
|-----------|----------|-------|
| `OpenvoxLint::Error` | `StandardError` | General errors (syntax, unterminated strings) |
| `OpenvoxLint::NoFix` | `StandardError` | Raised by `fix()` to skip unfixable problems |

#### Example Usage

```ruby
require 'openvox-lint'

# Configure globally
OpenvoxLint.configure do |c|
  c.fail_on_warnings = true
  c.ignore_paths = ['vendor/**/*.pp']
end

# Access check registry
OpenvoxLint.checks.keys  # => [:trailing_whitespace, :legacy_facts, ...]
```

---

### Class: OpenvoxLint::Token

Represents a single token produced by the lexer.  Tokens are linked in a
doubly-linked list for easy forward/backward navigation during checks.

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `type` | `Symbol` | Token type (see Token Types Reference) |
| `value` | `String` | Raw text value including quotes for strings |
| `line` | `Integer` | 1-based line number |
| `column` | `Integer` | 1-based column number |
| `prev_token` | `Token\|nil` | Previous token in doubly-linked list |
| `next_token` | `Token\|nil` | Next token in doubly-linked list |

#### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `#formatting?` | `Boolean` | True if whitespace, indent, newline, or comment |
| `#to_s` | `String` | Human-readable representation |
| `#inspect` | `String` | Debug representation |

#### Formatting Token Types

The following types return `true` for `#formatting?`:

- `:WHITESPACE` — spaces/tabs not at line start
- `:INDENT` — spaces/tabs at line start
- `:NEWLINE` — line breaks
- `:COMMENT` — `#` comments
- `:MLCOMMENT` — `/* */` block comments
- `:SLASH_COMMENT` — `//` comments

---

### Class: OpenvoxLint::Lexer

Tokenises a Puppet/OpenVox manifest string into an array of Token objects.
Recognises all Puppet 8 / OpenVox 8.x language constructs.

#### Constructor

```ruby
lexer = OpenvoxLint::Lexer.new(code_string)
```

Raises `OpenvoxLint::Error` for unterminated strings, regex, or heredocs.

#### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `tokens` | `Array<Token>` | All tokens (doubly-linked) |
| `manifest_lines` | `Array<String>` | Source lines (for line-based checks) |

#### Supported Constructs

- All Puppet keywords (class, define, if, case, etc.)
- Variables (`$foo`, `$::bar::baz`)
- Single and double-quoted strings with escape handling
- String interpolation (`"Hello ${name}"`)
- Heredocs (`@("END")`)
- Regular expressions (`/pattern/`)
- All operators (`=>`, `->`, `~>`, `==`, etc.)
- Class references (`File`, `String`, `Stdlib::Absolutepath`)
- Numbers (decimal, hex, octal, float, scientific)
- Comments (`#`, `/* */`, `//`)

---

### Class: OpenvoxLint::CheckPlugin

Base class for all lint checks.  Create new checks via `OpenvoxLint.new_check`.

#### Subclass Interface

| Method | Required | Description |
|--------|----------|-------------|
| `#check` | **Yes** | Main check logic; call `notify` to report problems |
| `#fix(problem)` | No | Auto-fix a problem; raise `NoFix` to skip |

#### Helper Methods Available in Checks

| Method | Returns | Description |
|--------|---------|-------------|
| `tokens` | `Array<Token>` | Full token stream |
| `manifest_lines` | `Array<String>` | Source lines (0-indexed) |
| `semantic_tokens` | `Array<Token>` | Non-formatting tokens only |
| `resource_indexes` | `Array<Hash>` | Resource body locations with param_tokens |
| `class_indexes` | `Array<Hash>` | Class definition locations |
| `defined_type_indexes` | `Array<Hash>` | Defined type locations |
| `node_indexes` | `Array<Hash>` | Node definition locations |
| `title_tokens` | `Array<Token>` | Resource title tokens |
| `fullpath` | `String` | Full file path being checked |
| `filename` | `String` | Base filename |
| `notify(kind, details)` | — | Report a problem |

#### `notify` Parameters

```ruby
notify :warning,    # or :error
  message: 'description of problem',
  line:    42,
  column:  5
```

#### Resource Index Structure

```ruby
{
  type: Token,           # Resource type token (e.g., "file")
  start: Integer,        # Semantic token index of opening brace
  end: Integer,          # Semantic token index of closing brace
  param_tokens: Array    # Tokens inside the resource body
}
```

---

### Class: OpenvoxLint::Configuration

Holds all runtime configuration for a lint session.

#### Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `log_format` | `String` | `'text'` | Output format |
| `with_filename` | `Boolean` | `true` | Show filename in output |
| `fail_on_warnings` | `Boolean` | `false` | Exit 1 on warnings |
| `fix` | `Boolean` | `false` | Auto-fix mode |
| `only_checks` | `Array<Symbol>` | `[]` | Run only these checks |
| `disabled_checks` | `Array<Symbol>` | `[]` | Skip these checks |
| `ignore_paths` | `Array<String>` | `['vendor/**/*.pp', 'pkg/**/*.pp', 'spec/**/*.pp']` | Glob patterns to ignore |
| `relative` | `Boolean` | `false` | Use relative paths in output |
| `column` | `Boolean` | `true` | Show column numbers |
| `custom_log_format` | `String\|nil` | `nil` | Custom format string |

#### Methods

| Method | Description |
|--------|-------------|
| `#load_from_rc(path)` | Load config from an RC file |
| `#check_enabled?(name)` | Returns true if check is enabled |

#### RC File Format

```
# .openvox-lint.rc
# Each line is a command-line flag

--no-line_length-check
--no-documentation-check
--fail-on-warnings
--ignore-paths vendor/**/*.pp,pkg/**/*.pp
```

---

### Class: OpenvoxLint::Linter

Orchestrates the linting of one or more manifest files.

#### Constructor

```ruby
linter = OpenvoxLint::Linter.new(configuration: config)
```

#### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `#run(*paths)` | — | Lint files/directories |
| `#problems` | `Array<Hash>` | All detected problems |
| `#file_count` | `Integer` | Number of files checked |
| `#errors?` | `Boolean` | Any errors found? |
| `#warnings?` | `Boolean` | Any warnings found? |
| `#exit_code` | `Integer` | 0=clean, 1=problems |

#### Problem Hash Structure

```ruby
{
  path:    'manifests/init.pp',
  line:    42,
  column:  5,
  kind:    :warning,  # or :error
  check:   :legacy_facts,
  message: "legacy fact 'osfamily' — use $facts['...']"
}
```

#### Usage Example

```ruby
require 'openvox-lint'

config = OpenvoxLint::Configuration.new
config.fail_on_warnings = true
config.only_checks = [:legacy_facts, :hiera3_function]

linter = OpenvoxLint::Linter.new(configuration: config)
linter.run('manifests/')

puts "Checked #{linter.file_count} files"
puts "Found #{linter.problems.size} problems"
exit linter.exit_code
```

---

### Class: OpenvoxLint::Report

Formats and outputs lint problems in various formats.

#### Constructor

```ruby
report = OpenvoxLint::Report.new(configuration)
```

#### Methods

| Method | Description |
|--------|-------------|
| `#format(problems, io: $stdout)` | Format and output problems |

#### Supported Formats

| Format | Flag | Description |
|--------|------|-------------|
| `text` | `-f text` (default) | `path:line:col: KIND: check: message` |
| `json` | `-f json` | JSON array of problem objects |
| `csv` | `-f csv` | CSV with headers |
| `github` | `-f github` | GitHub Actions annotations |
| `codeclimate` | `-f codeclimate` | Code Climate JSON format |
| `custom` | `--log-format` | User-defined format string |

#### Custom Format Placeholders

| Placeholder | Value |
|-------------|-------|
| `%{path}` | File path |
| `%{line}` | Line number |
| `%{column}` | Column number |
| `%{KIND}` | Uppercase severity (WARNING/ERROR) |
| `%{kind}` | Lowercase severity |
| `%{check}` | Check name |
| `%{message}` | Problem message |

---

## Complete Check Reference (37 Checks)

### Whitespace & Formatting (5 checks)

#### `trailing_whitespace` (WARNING)

Detects trailing whitespace at the end of lines.

**Why:** Trailing whitespace is invisible noise that pollutes diffs and can cause
merge conflicts.

**Bad:**
```puppet
class foo {   
  ensure => present,  
}
```

**Good:**
```puppet
class foo {
  ensure => present,
}
```

---

#### `hard_tabs` (WARNING)

Detects hard tab characters.  Puppet style requires 2-space soft tabs.

**Why:** Tabs render inconsistently across editors and terminals.  The Puppet
Style Guide mandates 2-space indentation.

**Bad:**
```puppet
class foo {
	ensure => present,
}
```

**Good:**
```puppet
class foo {
  ensure => present,
}
```

---

#### `line_length` (WARNING)

Lines should not exceed 140 characters.

**Why:** Long lines are hard to read, especially in code review and side-by-side
diffs.  The check has a built-in exception for long `puppet:///` URLs which
often cannot be broken.

**Bad:**
```puppet
file { '/etc/config': content => 'This is a very long string that exceeds the maximum line length limit and makes the code hard to read in most editors and code review tools' }
```

**Good:**
```puppet
$content = 'This is a long string that has been assigned to a variable'

file { '/etc/config':
  content => $content,
}
```

---

#### `strict_indent` (WARNING)

Indentation must use 2-space increments.  Flags lines with odd numbers of
leading spaces.

**Why:** Consistent indentation improves readability.  Puppet convention is
exactly 2 spaces per nesting level.

**Bad:**
```puppet
class foo {
   ensure => present,  # 3 spaces - odd!
}
```

**Good:**
```puppet
class foo {
  ensure => present,   # 2 spaces
}
```

---

#### `space_before_arrow` (WARNING)

In aligned parameter blocks, only the longest key should have exactly one space
before `=>`.  Extra spaces on the longest key indicate over-padding.

**Why:** When arrows are aligned, shorter keys need padding.  But the longest
key sets the alignment column and should have exactly one space.

**Good — properly aligned:**
```puppet
file { '/etc/nginx/nginx.conf':
  ensure  => file,
  content => template('nginx/nginx.conf.erb'),
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
}
```

Here `content` (7 chars) is the longest key with 1 space before `=>`.
Other keys have padding spaces for alignment.

**Bad — longest key has extra space:**
```puppet
file { '/tmp/foo':
  ensure  => present,
  mode    => '0644',
}
```

`ensure` is longest (6 chars) but has 2 spaces before `=>`.

**Bad — single parameter with extra space:**
```puppet
package { 'httpd':
  ensure   => installed,
}
```

One parameter means nothing to align with — extra spaces flagged.

---

### Arrow Alignment (1 check)

#### `arrow_alignment` (WARNING)

Hash rockets (`=>`) should be aligned within a resource body.  This check
groups arrows by line proximity and flags any that are not at the maximum
column position for that group.

**Why:** Vertical alignment improves readability of resource declarations.
It makes it easy to scan parameter values at a glance.

**Note:** This check coordinates with `space_before_arrow` to avoid
contradictory warnings.  If misalignment is caused by extra spaces before
the longest key's arrow, only `space_before_arrow` fires.

**Bad — misaligned arrows:**
```puppet
file { '/tmp/foo':
  ensure => file,
  content => 'hello',
  mode => '0644',
}
```

**Good — aligned arrows:**
```puppet
file { '/tmp/foo':
  ensure  => file,
  content => 'hello',
  mode    => '0644',
}
```

---

### Quoting & Strings (5 checks)

#### `double_quoted_strings` (WARNING)

Double-quoted strings that contain no variables or escape sequences should
use single quotes instead.

**Exception:** If the string contains literal single-quote characters
(`'`), double quotes are correct to avoid escaping.

**Why:** Single quotes signal "this is a literal string" while double quotes
signal "this may contain interpolation".  Using single quotes when possible
makes intent clearer.

**Bad:**
```puppet
file { "/tmp/foo":
  ensure => "present",
}
```

**Good:**
```puppet
file { '/tmp/foo':
  ensure => 'present',
}
```

**Exception — nested single quotes (allowed):**
```puppet
notify { "It's working":
  message => "Use 'ensure' as first parameter",
}
```

---

#### `only_variable_string` (WARNING)

A string containing only a variable should not be quoted.

**Why:** `"${foo}"` is semantically identical to `$foo` but adds visual noise
and suggests interpolation where none occurs.

**Bad:**
```puppet
$result = "${some_variable}"
file { "${path}": }
```

**Good:**
```puppet
$result = $some_variable
file { $path: }
```

---

#### `single_quote_string_with_variables` (WARNING)

Single-quoted strings containing `$variable` patterns should use double
quotes for interpolation.

**Why:** Variables in single-quoted strings are literal text, not interpolated.
This is usually a mistake.

**Bad:**
```puppet
notify { 'hello':
  message => 'Hello $name, welcome!',  # $name is literal
}
```

**Good:**
```puppet
notify { 'hello':
  message => "Hello ${name}, welcome!",  # $name is interpolated
}
```

---

#### `variables_not_enclosed` (WARNING)

Variables in double-quoted strings should be enclosed in braces (`${var}`).

**Why:** Brace syntax makes variable boundaries explicit and allows array/hash
access.  `$foo` works but `${foo}` is clearer, especially with adjacent text.

**Bad:**
```puppet
$msg = "Hello $name!"
$path = "/home/$user/bin"
```

**Good:**
```puppet
$msg = "Hello ${name}!"
$path = "/home/${user}/bin"
```

**Mixed handling:** A string with both enclosed and unenclosed variables
correctly flags only the unenclosed ones:

```puppet
$msg = "Hello $name, your home is ${home}"  # Only $name flagged
```

---

#### `quoted_booleans` (WARNING)

Boolean values `true` and `false` should not be quoted.

**Why:** Quoted booleans are strings, not booleans.  `'true'` is truthy
because it's a non-empty string, but it won't work correctly with strict
boolean comparisons or type checking.

**Bad:**
```puppet
$enabled = 'true'
service { 'nginx': enable => "false" }
```

**Good:**
```puppet
$enabled = true
service { 'nginx': enable => false }
```

---

### Variables (2 checks)

#### `variable_is_lowercase` (WARNING)

Variable names must be lowercase.  Names may contain underscores and colons
(for namespaced variables).

**Why:** Puppet convention is lowercase variables.  Mixed case can cause
confusion with class references which are capitalised.

**Bad:**
```puppet
$MyVariable = 'value'
$DatabasePort = 5432
```

**Good:**
```puppet
$my_variable = 'value'
$database_port = 5432
```

---

#### `variable_contains_dash` (WARNING)

Variable names must not contain dashes (hyphens).

**Why:** Dashes are not valid in Puppet variable names.  The parser may
interpret them as subtraction operations.

**Bad:**
```puppet
$my-variable = 'value'
```

**Good:**
```puppet
$my_variable = 'value'
```

---

### Resources (7 checks)

#### `ensure_first_param` (WARNING)

The `ensure` attribute should be the first parameter in a resource body.

**Why:** `ensure` is the most important attribute — it determines whether
the resource exists.  Placing it first makes resource declarations scannable.

**Bad:**
```puppet
file { '/tmp/foo':
  owner  => 'root',
  ensure => file,
  mode   => '0644',
}
```

**Good:**
```puppet
file { '/tmp/foo':
  ensure => file,
  owner  => 'root',
  mode   => '0644',
}
```

---

#### `ensure_not_symlink_target` (WARNING)

Symlinks should use `ensure => link` with a `target` attribute, not
`ensure => '/path/to/target'`.

**Why:** Setting `ensure` to a path is confusing.  The explicit `link` +
`target` syntax is clearer and matches documentation examples.

**Bad:**
```puppet
file { '/usr/local/bin/python':
  ensure => '/usr/bin/python3',
}
```

**Good:**
```puppet
file { '/usr/local/bin/python':
  ensure => link,
  target => '/usr/bin/python3',
}
```

---

#### `file_mode` (WARNING)

File modes should be 4-digit quoted octal strings or symbolic modes.

**Why:** 3-digit modes are ambiguous (is `644` the same as `0644`?).
Unquoted numbers can be misinterpreted.  Symbolic modes (`u+x`) are allowed.

**Bad:**
```puppet
file { '/tmp/foo':
  mode => 644,      # Unquoted, 3 digits
}
file { '/tmp/bar':
  mode => '755',    # Only 3 digits
}
```

**Good:**
```puppet
file { '/tmp/foo':
  mode => '0644',   # 4-digit quoted octal
}
file { '/tmp/bar':
  mode => 'u+x',    # Symbolic mode
}
```

---

#### `unquoted_file_mode` (WARNING)

File modes must be quoted strings, not bare numbers.

**Why:** Numeric file modes are parsed as integers.  `0644` is valid octal,
but `644` might be decimal.  Quoting removes ambiguity.

**Bad:**
```puppet
file { '/tmp/foo':
  mode => 0644,
}
```

**Good:**
```puppet
file { '/tmp/foo':
  mode => '0644',
}
```

---

#### `unquoted_resource_title` (WARNING)

Resource titles should be quoted strings, not bare words.

**Why:** Bare word titles can be confused with variables or cause unexpected
behaviour.  Quoting makes intent explicit.

**Bad:**
```puppet
file { tmpfile:
  ensure => file,
}
```

**Good:**
```puppet
file { '/tmp/file':
  ensure => file,
}
file { 'configuration file':
  path   => '/etc/app.conf',
  ensure => file,
}
```

---

#### `duplicate_params` (ERROR)

No duplicate parameters in resource declarations.

**Why:** Duplicate parameters are almost always mistakes.  The last value
wins, which can cause subtle bugs.

**Bad:**
```puppet
file { '/tmp/foo':
  ensure => file,
  owner  => 'root',
  owner  => 'nobody',  # Duplicate!
}
```

**Good:**
```puppet
file { '/tmp/foo':
  ensure => file,
  owner  => 'root',
}
```

---

#### `trailing_comma` (WARNING)

Resource bodies should end with a trailing comma after the last attribute.

**Why:** Trailing commas make diffs cleaner when adding new attributes.
They also prevent syntax errors when copy-pasting.

**Note:** Only fires inside resource bodies (`name { ... }`), not inside
conditionals, class bodies, or other brace contexts.

**Bad:**
```puppet
file { '/tmp/foo':
  ensure => file,
  owner  => 'root'
}
```

**Good:**
```puppet
file { '/tmp/foo':
  ensure => file,
  owner  => 'root',
}
```

---

### Classes & Defines (5 checks)

#### `documentation` (WARNING)

Classes and defined types should be preceded by documentation comments.

**Why:** Documentation helps users understand what a class does without
reading the implementation.  Puppet Strings extracts these comments.

**Bad:**
```puppet
class mymodule::webserver {
  # ...
}
```

**Good:**
```puppet
# Configures an Nginx webserver with standard settings.
#
# @param port The port to listen on.
# @param ssl Enable SSL termination.
class mymodule::webserver (
  Integer $port = 80,
  Boolean $ssl  = false,
) {
  # ...
}
```

---

#### `nested_classes_or_defines` (WARNING)

Classes and defined types should not be nested inside other classes or
defined types.

**Why:** Nested definitions are confusing and don't work as expected.
Use separate files and include/contain for composition.

**Bad:**
```puppet
class outer {
  class inner {  # Nested!
    # ...
  }
}
```

**Good:**
```puppet
# outer.pp
class outer {
  contain outer::inner
}

# inner.pp
class outer::inner {
  # ...
}
```

---

#### `parameter_order` (WARNING)

Parameters without defaults should come before parameters with defaults.

**Why:** When calling a class, required parameters must be specified.
Listing them first makes the required inputs obvious.

**Bad:**
```puppet
class myclass (
  $optional = 'default',
  $required,  # No default, but after one with default!
) {
}
```

**Good:**
```puppet
class myclass (
  $required,
  $optional = 'default',
) {
}
```

---

#### `class_inherits_params` (WARNING)

Class inheritance is discouraged.  Use composition (include, contain, require)
instead.

**Why:** Class inheritance was an early Puppet feature that causes confusion.
Composition is more flexible and easier to understand.

**Bad:**
```puppet
class mymodule::child inherits mymodule::parent {
  # ...
}
```

**Good:**
```puppet
class mymodule::child {
  contain mymodule::parent
  # ...
}
```

---

#### `inherits_across_namespaces` (WARNING)

Classes should not inherit across module namespaces.

**Why:** Cross-namespace inheritance creates tight coupling between modules.
It makes modules harder to maintain and test independently.

**Bad:**
```puppet
class mymodule::foo inherits othermodule::bar {
  # Inheriting from a different module!
}
```

**Good:**
```puppet
class mymodule::foo {
  contain othermodule::bar  # Composition instead
}
```

---

### Conditionals (2 checks)

#### `case_without_default` (WARNING)

Case statements must have a `default` case.

**Why:** Without a default, unexpected values silently do nothing.
Explicit defaults catch mistakes and document expected behaviour.

**Bad:**
```puppet
case $os {
  'RedHat': { include redhat }
  'Debian': { include debian }
}
```

**Good:**
```puppet
case $os {
  'RedHat': { include redhat }
  'Debian': { include debian }
  default:  { fail("Unsupported OS: ${os}") }
}
```

---

#### `selector_inside_resource` (WARNING)

Selectors (`?`) should not be used inside resource declarations.

**Why:** Selectors inside resource bodies reduce readability.  Extract
the logic to a variable or use a conditional outside the resource.

**Bad:**
```puppet
file { '/etc/app.conf':
  content => $env ? {
    'prod' => template('app/prod.erb'),
    default => template('app/dev.erb'),
  },
}
```

**Good:**
```puppet
$config_template = $env ? {
  'prod'  => 'app/prod.erb',
  default => 'app/dev.erb',
}

file { '/etc/app.conf':
  content => template($config_template),
}
```

---

### References & Syntax (3 checks)

#### `leading_zero` (WARNING)

Numbers should not have leading zeros (except octal file modes).

**Why:** Leading zeros indicate octal notation.  `010` is 8, not 10.
This is a common source of bugs.

**Exception:** The check allows leading zeros after `mode =>` for file modes.

**Bad:**
```puppet
$count = 010     # This is 8 in octal!
$port = 0080     # This is 64!
```

**Good:**
```puppet
$count = 10
$port = 80
file { '/tmp/foo': mode => '0644' }  # Allowed for mode
```

---

#### `resource_reference_without_title_capital` (WARNING)

Resource reference types must start with a capital letter.

**Why:** Resource references use capitalised type names: `File['/tmp']`,
not `file['/tmp']`.  Lowercase looks like an array access.

**Note:** The check has an allowlist of 40+ functions that use bracket
syntax (`each`, `map`, `filter`, `lookup`, etc.) to avoid false positives.

**Bad:**
```puppet
require file['/etc/config']
```

**Good:**
```puppet
require File['/etc/config']
```

---

#### `autoloader_layout` (WARNING)

Class and define names should match the autoloader file path.

**Why:** Puppet's autoloader expects `class foo::bar::baz` in
`foo/manifests/bar/baz.pp`.  Mismatches cause "class not found" errors.

**Bad:**
```puppet
# In mymodule/manifests/init.pp
class mymodule::subclass {  # Should be in subclass.pp
}
```

**Good:**
```puppet
# In mymodule/manifests/init.pp
class mymodule {
}

# In mymodule/manifests/subclass.pp
class mymodule::subclass {
}
```

---

### Comments (1 check)

#### `star_comments` (WARNING)

Use `#` hash comments, not `/* */` block comments.

**Why:** Hash comments are the standard in Puppet.  Block comments are
inherited from C-style languages and less common in the ecosystem.

**Bad:**
```puppet
/* This is a block comment
   that spans multiple lines */
class foo {
}
```

**Good:**
```puppet
# This is a hash comment
# that spans multiple lines
class foo {
}
```

---

### URLs (1 check)

#### `puppet_url_without_modules` (WARNING)

`puppet:///` URLs should include the `/modules/` mount point.

**Why:** The full URL format is `puppet:///modules/modulename/path`.
Omitting `/modules/` causes file not found errors.

**Bad:**
```puppet
file { '/etc/config':
  source => 'puppet:///mymodule/config',
}
```

**Good:**
```puppet
file { '/etc/config':
  source => 'puppet:///modules/mymodule/config',
}
```

---

### Nodes (1 check)

#### `node_name_unquoted` (WARNING)

Node names should be quoted strings, not bare words.

**Why:** Quoted names make intent explicit and avoid potential parsing
issues with special characters.

**Bad:**
```puppet
node webserver01 {
}
```

**Good:**
```puppet
node 'webserver01' {
}

node 'webserver01.example.com' {
}
```

---

### Puppet 8 / OpenVox 8 Compatibility (4 checks)

These checks are critical for users upgrading from Puppet 7 or migrating
to OpenVox 8.  They detect patterns that will break or behave differently
in the new version.

#### `legacy_facts` (WARNING)

Legacy (unstructured) top-scope facts are excluded by default in Puppet 8 /
OpenVox 8.  Over 80 legacy fact names are detected.

**Why:** Puppet 8 excludes legacy facts by default.  Code using `$osfamily`
will break unless the agent is configured to include legacy facts (not
recommended for new code).

**Bad:**
```puppet
if $osfamily == 'RedHat' { }
$host = $fqdn
$ip = $ipaddress
$os = $operatingsystem
```

**Good:**
```puppet
if $facts['os']['family'] == 'RedHat' { }
$host = $facts['networking']['fqdn']
$ip = $facts['networking']['ip']
$os = $facts['os']['name']
```

**Detected legacy facts include:** `architecture`, `bios_*`, `domain`,
`fqdn`, `hostname`, `id`, `interfaces`, `ipaddress`, `ipaddress6`,
`kernel`, `kernelrelease`, `macaddress`, `memoryfree`, `memorysize`,
`netmask`, `network`, `operatingsystem`, `operatingsystemrelease`,
`osfamily`, `processorcount`, `puppetversion`, `rubyversion`,
`selinux*`, `swapfree`, `swapsize`, `timezone`, `uptime*`, `virtual`,
and many more.

---

#### `top_scope_facts` (WARNING)

Top-scope fact variables (`$::factname`) are deprecated.  Use the `$facts`
hash instead.

**Why:** The `$::` prefix was needed in older Puppet to explicitly reference
top-scope variables.  Modern Puppet provides the `$facts` hash which is
clearer and more consistent.

**Note:** This check only flags simple facts, not module-qualified variables
like `$::mymodule::param` which are legitimate.

**Bad:**
```puppet
$hostname = $::hostname
$os = $::operatingsystem
if $::selinux { }
```

**Good:**
```puppet
$hostname = $facts['networking']['hostname']
$os = $facts['os']['name']
if $facts['selinux'] { }
```

---

#### `hiera3_function` (ERROR)

Deprecated Hiera 3 functions (`hiera`, `hiera_array`, `hiera_hash`, `hiera_include`)
are **removed** in Puppet 8 / OpenVox 8.  Use the Hiera 5 `lookup()` function instead.

**Why:** Hiera 3 is fully deprecated.  Only **Hiera 5** is supported in Puppet 8 /
OpenVox 8.  The legacy `hiera()` functions were compatibility shims that have been
removed.  This is an error, not a warning, because the code will fail immediately.

**Bad — deprecated Hiera 3 functions:**
```puppet
$val = hiera('mykey')
$list = hiera_array('mylist')
$hash = hiera_hash('myhash')
hiera_include('classes')
```

**Good — Hiera 5 lookup() function:**
```puppet
$val = lookup('mykey')
$list = lookup('mylist', Array, 'unique')
$hash = lookup('myhash', Hash, 'hash')
lookup('classes', Array[String], 'unique').include
```

**Hiera 5 Features:**
- Single `lookup()` function replaces all Hiera 3 functions
- Supports type validation: `lookup('key', String)`
- Supports merge strategies: `'first'`, `'unique'`, `'hash'`, `'deep'`
- Supports default values: `lookup('key', String, 'first', 'default_value')`
- Works with module-level `hiera.yaml` configuration

---

#### `import_statement` (ERROR)

The `import` keyword was removed in Puppet 4.

**Why:** This is an error because the code will fail to parse.  Use
module autoloading instead.

**Bad:**
```puppet
import 'foo'
import 'nodes/*.pp'
```

**Good:**

Use the module autoloader by placing files in the correct location:
- `modules/mymodule/manifests/init.pp` for `class mymodule`
- `modules/mymodule/manifests/subclass.pp` for `class mymodule::subclass`

---

## Token Types Reference

### Keywords

| Type | Keyword | Type | Keyword |
|------|---------|------|---------|
| `:AND` | `and` | `:APPLICATION` | `application` |
| `:ATTR` | `attr` | `:CASE` | `case` |
| `:CLASS` | `class` | `:CONSUMES` | `consumes` |
| `:DEFAULT` | `default` | `:DEFINE` | `define` |
| `:ELSE` | `else` | `:ELSIF` | `elsif` |
| `:FALSE` | `false` | `:FUNCTION` | `function` |
| `:IF` | `if` | `:IMPORT` | `import` |
| `:IN` | `in` | `:INHERITS` | `inherits` |
| `:NODE` | `node` | `:NOT` | `not` |
| `:OR` | `or` | `:PRIVATE` | `private` |
| `:PRODUCES` | `produces` | `:SITE` | `site` |
| `:TRUE` | `true` | `:TYPE` | `type` |
| `:UNDEF` | `undef` | `:UNLESS` | `unless` |

### Identifiers & Literals

| Type | Description | Example |
|------|-------------|---------|
| `:NAME` | Identifier / bare word | `ensure`, `myclass` |
| `:CLASSREF` | Capitalised type reference | `File`, `String`, `Stdlib::Absolutepath` |
| `:VARIABLE` | Variable (includes `$`) | `$foo`, `$::bar::baz` |
| `:NUMBER` | Numeric literal | `42`, `0xFF`, `0755`, `3.14`, `1e10` |
| `:SSTRING` | Single-quoted string | `'hello'` |
| `:STRING` | Double-quoted string (no interpolation) | `"hello"` |
| `:DQSTRING` | Double-quoted string (with interpolation) | `"hello ${name}"` |
| `:REGEX` | Regular expression | `/^foo/` |
| `:HEREDOC_OPEN` | Heredoc opening tag | `@("END")` |
| `:HEREDOC` | Heredoc body content | (multi-line content) |

### Operators

| Type | Operator | Description |
|------|----------|-------------|
| `:FARROW` | `=>` | Hash rocket (parameter assignment) |
| `:PARROW` | `+>` | Append to array attribute |
| `:ISEQUAL` | `==` | Equality |
| `:NOTEQUAL` | `!=` | Inequality |
| `:MATCH` | `=~` | Regex match |
| `:NOMATCH` | `!~` | Regex non-match |
| `:LESSEQUAL` | `<=` | Less than or equal |
| `:GREATEREQUAL` | `>=` | Greater than or equal |
| `:LESSTHAN` | `<` | Less than |
| `:GREATERTHAN` | `>` | Greater than |
| `:LSHIFT` | `<<` | Left shift |
| `:RSHIFT` | `>>` | Right shift |
| `:IN_EDGE` | `->` | Ordering (before) |
| `:OUT_EDGE` | `<-` | Ordering (after) |
| `:IN_EDGE_SUB` | `~>` | Ordering with notify |
| `:OUT_EDGE_SUB` | `<~` | Reverse ordering with notify |
| `:APPENDS` | `+=` | Append assignment |
| `:EQUALS` | `=` | Assignment |
| `:LCOLLECT` | `<\|` | Collection query open |
| `:RCOLLECT` | `\|>` | Collection query close |
| `:LLCOLLECT` | `<<\|` | Exported collection query open |
| `:RRCOLLECT` | `\|>>` | Exported collection query close |

### Punctuation

| Type | Character | Type | Character |
|------|-----------|------|-----------|
| `:LBRACE` | `{` | `:RBRACE` | `}` |
| `:LPAREN` | `(` | `:RPAREN` | `)` |
| `:LBRACK` | `[` | `:RBRACK` | `]` |
| `:COMMA` | `,` | `:SEMIC` | `;` |
| `:DOT` | `.` | `:COLON` | `:` |
| `:PIPE` | `\|` | `:AT` | `@` |
| `:QMARK` | `?` | `:BACKSLASH` | `\\` |
| `:PLUS` | `+` | `:MINUS` | `-` |
| `:TIMES` | `*` | `:MODULO` | `%` |
| `:DIV` | `/` | `:NOT` | `!` |

### Formatting Tokens

| Type | Description |
|------|-------------|
| `:WHITESPACE` | Spaces/tabs (not at line start) |
| `:INDENT` | Spaces/tabs at line start |
| `:NEWLINE` | Line break (`\n` or `\r\n`) |
| `:COMMENT` | Hash comment (`# ...`) |
| `:MLCOMMENT` | Multi-line comment (`/* ... */`) |
| `:SLASH_COMMENT` | C++ style comment (`// ...`) |

---

## Plugin Development

### Creating a Check Plugin

```ruby
# lib/openvox-lint/plugins/checks/my_custom_check.rb
OpenvoxLint.new_check(:my_custom_check) do
  def check
    tokens.each do |tok|
      if tok.type == :NAME && tok.value == 'deprecated_function'
        notify :warning,
          message: 'deprecated_function() is obsolete',
          line: tok.line,
          column: tok.column
      end
    end
  end

  # Optional: implement auto-fix
  def fix(problem)
    # Find and modify the problematic token
    # Or raise NoFix if this instance can't be fixed
    raise OpenvoxLint::NoFix
  end
end
```

### Using Helper Methods

```ruby
OpenvoxLint.new_check(:resource_check) do
  def check
    # Check only resource bodies
    resource_indexes.each do |resource|
      type_name = resource[:type].value
      next unless type_name == 'file'
      
      # Examine parameters
      resource[:param_tokens].each do |tok|
        # Check parameter values
      end
    end
  end
end
```

### Line-Based Checks

```ruby
OpenvoxLint.new_check(:line_based_check) do
  def check
    manifest_lines.each_with_index do |line, idx|
      if line =~ /FIXME|TODO/
        notify :warning,
          message: 'TODO/FIXME comment found',
          line: idx + 1,  # Lines are 1-indexed in output
          column: 1
      end
    end
  end
end
```

### Distributing as a Gem

```ruby
# openvox-lint-my_checks.gemspec
Gem::Specification.new do |spec|
  spec.name = 'openvox-lint-my_checks'
  spec.version = '1.0.0'
  spec.summary = 'Custom checks for openvox-lint'
  
  spec.add_runtime_dependency 'openvox-lint', '~> 1.0'
  
  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']
end
```

Place check files in `lib/openvox-lint/plugins/checks/` and they will
be auto-loaded when the gem is required.

---

## Migration from puppet-lint

openvox-lint is designed as a modern replacement for puppet-lint with
broader compatibility and additional checks.

### Key Differences

| Feature | puppet-lint 5.x | openvox-lint 1.x |
|---------|-----------------|------------------|
| Ruby requirement | ≥ 3.1 | ≥ 2.5 (works on RHEL 8, macOS system Ruby) |
| Runtime dependencies | None | None |
| Built-in checks | ~25 | 37 |
| Legacy facts detection | Via plugin | Built-in |
| Top-scope facts detection | Via plugin | Built-in |
| Deprecated Hiera 3 function detection | No | Built-in (ERROR) |
| Import statement detection | No | Built-in (ERROR) |
| Strict indent check | Via plugin | Built-in |
| GitHub Actions output | No | Built-in (`-f github`) |
| Code Climate output | No | Built-in (`-f codeclimate`) |
| CSV output | No | Built-in (`-f csv`) |
| OpenVox awareness | No | Yes |
| `--fix` support | Yes | Yes |
| Plugin system | Yes | Yes (compatible API) |

### Command-Line Compatibility

Most puppet-lint flags work identically:

```bash
# These work the same way
puppet-lint --no-documentation-check manifests/
openvox-lint --no-documentation-check manifests/

puppet-lint --only-checks legacy_facts,hiera3_function .
openvox-lint --only-checks legacy_facts,hiera3_function .

puppet-lint --log-format '%{path}:%{line}:%{KIND}' .
openvox-lint --log-format '%{path}:%{line}:%{KIND}' .
```

### RC File Migration

Rename `.puppet-lint.rc` to `.openvox-lint.rc`.  The format is identical:

```bash
# .openvox-lint.rc
--no-documentation-check
--no-line_length-check
--fail-on-warnings
```

### Plugin Migration

Plugin APIs are similar.  Main differences:

1. Module name: `OpenvoxLint` instead of `PuppetLint`
2. Check registration: `OpenvoxLint.new_check(:name)` instead of `PuppetLint.new_check(:name)`

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | No errors found (warnings allowed unless `--fail-on-warnings`) |
| `1` | Errors found, or warnings found with `--fail-on-warnings` |

---

## File Inventory

| File | Description |
|------|-------------|
| `bin/openvox-lint` | CLI entry point (Ruby executable) |
| `lib/openvox-lint.rb` | Main module, auto-loads all components |
| `lib/openvox-lint/version.rb` | Version constant |
| `lib/openvox-lint/configuration.rb` | Configuration management |
| `lib/openvox-lint/token.rb` | Token data structure |
| `lib/openvox-lint/lexer.rb` | Puppet/OpenVox manifest lexer |
| `lib/openvox-lint/check_plugin.rb` | Base class for check plugins |
| `lib/openvox-lint/checks.rb` | Check runner with lint:ignore support |
| `lib/openvox-lint/report.rb` | Output formatters (text, json, etc.) |
| `lib/openvox-lint/linter.rb` | File discovery and orchestration |
| `lib/openvox-lint/cli.rb` | Command-line interface |
| `lib/openvox-lint/plugins/checks/*.rb` | 37 built-in check plugins |
| `spec/spec_helper.rb` | RSpec test helper |
| `spec/unit/lexer_spec.rb` | Lexer unit tests |
| `spec/unit/checks_spec.rb` | Check unit tests |
| `openvox-lint.gemspec` | Gem specification |
| `Gemfile` | Development dependencies |
| `Rakefile` | Rake tasks |
| `LICENSE` | Apache 2.0 license |
| `README.md` | User documentation |
| `CHANGELOG.md` | Version history |
| `DOCUMENTATION.md` | This file |
