# openvox-lint Technical Documentation

## Overview

openvox-lint is a Ruby gem that statically analyses OpenVox / Puppet manifest
(`.pp`) files.  It tokenises each file with a purpose-built lexer, then runs
a configurable set of check plugins against the token stream.  Problems are
reported in multiple output formats suitable for humans, CI systems, and IDEs.

This document covers the architecture, every public API, every built-in check,
the lexer token types, the plugin system, and integration guidance.

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
3. **Lexer** tokenises the manifest into `Token` objects
4. **Checks** runs each enabled check plugin against the token stream
5. **Report** formats and outputs the collected problems

---

## Module: OpenvoxLint

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `VERSION` | `'1.0.1'` | Gem version |

### Class Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `.configuration` | `Configuration` | Global configuration singleton |
| `.configure { \|c\| }` | `Configuration` | Yields configuration for block-style setup |
| `.checks` | `Hash{Symbol => Class}` | Registry of loaded check classes |
| `.new_check(name, &block)` | `Class` | Register a new check plugin |

### Exceptions

| Exception | Inherits | Usage |
|-----------|----------|-------|
| `OpenvoxLint::Error` | `StandardError` | General errors |
| `OpenvoxLint::NoFix` | `StandardError` | Raised to skip fixing a problem |

---

## Class: OpenvoxLint::Token

Represents a single token from the lexer.

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `type` | `Symbol` | Token type (see Token Types below) |
| `value` | `String` | Raw text value |
| `line` | `Integer` | 1-based line number |
| `column` | `Integer` | 1-based column number |
| `prev_token` | `Token\|nil` | Previous token in doubly-linked list |
| `next_token` | `Token\|nil` | Next token in doubly-linked list |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `#formatting?` | `Boolean` | True if whitespace/comment/indent/newline |
| `#to_s` | `String` | Human-readable representation |

### Token Types

#### Keywords

| Type | Puppet Keyword |
|------|---------------|
| `:AND` | `and` |
| `:APPLICATION` | `application` |
| `:ATTR` | `attr` |
| `:CASE` | `case` |
| `:CLASS` | `class` |
| `:CONSUMES` | `consumes` |
| `:DEFAULT` | `default` |
| `:DEFINE` | `define` |
| `:ELSE` | `else` |
| `:ELSIF` | `elsif` |
| `:FALSE` | `false` |
| `:FUNCTION` | `function` |
| `:IF` | `if` |
| `:IMPORT` | `import` |
| `:IN` | `in` |
| `:INHERITS` | `inherits` |
| `:NODE` | `node` |
| `:NOT` | `not` |
| `:OR` | `or` |
| `:PRIVATE` | `private` |
| `:PRODUCES` | `produces` |
| `:SITE` | `site` |
| `:TRUE` | `true` |
| `:TYPE` | `type` |
| `:UNDEF` | `undef` |
| `:UNLESS` | `unless` |

#### Identifiers & Literals

| Type | Description | Example |
|------|-------------|---------|
| `:NAME` | Identifier / bare word | `ensure`, `myclass` |
| `:CLASSREF` | Capitalised reference | `File`, `String`, `Stdlib::Absolutepath` |
| `:VARIABLE` | Variable | `$foo`, `$::bar::baz` |
| `:NUMBER` | Numeric literal | `42`, `0xFF`, `3.14` |
| `:SSTRING` | Single-quoted string | `'hello'` |
| `:STRING` | Double-quoted string (no interpolation) | `"hello"` |
| `:DQSTRING` | Double-quoted string (with interpolation) | `"hello ${name}"` |
| `:REGEX` | Regular expression | `/^foo/` |
| `:HEREDOC_OPEN` | Heredoc opening tag | `@("END")` |
| `:HEREDOC` | Heredoc body | content |

#### Operators

| Type | Operator | Type | Operator |
|------|----------|------|----------|
| `:FARROW` | `=>` | `:PARROW` | `+>` |
| `:ISEQUAL` | `==` | `:NOTEQUAL` | `!=` |
| `:MATCH` | `=~` | `:NOMATCH` | `!~` |
| `:LESSEQUAL` | `<=` | `:GREATEREQUAL` | `>=` |
| `:LESSTHAN` | `<` | `:GREATERTHAN` | `>` |
| `:LSHIFT` | `<<` | `:RSHIFT` | `>>` |
| `:IN_EDGE` | `->` | `:OUT_EDGE` | `<-` |
| `:IN_EDGE_SUB` | `~>` | `:OUT_EDGE_SUB` | `<~` |
| `:APPENDS` | `+=` | `:EQUALS` | `=` |
| `:LCOLLECT` | `<\|` | `:RCOLLECT` | `\|>` |
| `:LLCOLLECT` | `<<\|` | `:RRCOLLECT` | `\|>>` |

#### Punctuation

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

#### Formatting

| Type | Description |
|------|-------------|
| `:WHITESPACE` | Spaces/tabs (not at line start) |
| `:INDENT` | Spaces/tabs at line start |
| `:NEWLINE` | Line break |
| `:COMMENT` | `#` comment |
| `:MLCOMMENT` | `/* */` comment |
| `:SLASH_COMMENT` | `//` comment |

---

## Class: OpenvoxLint::Lexer

### Constructor

```ruby
lexer = OpenvoxLint::Lexer.new(code_string)
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `tokens` | `Array<Token>` | All tokens (doubly-linked) |
| `manifest_lines` | `Array<String>` | Source lines (for line-based checks) |

---

## Class: OpenvoxLint::CheckPlugin

Base class for all checks. Created via `OpenvoxLint.new_check`.

### Subclass Interface

| Method | Required | Description |
|--------|----------|-------------|
| `#check` | **Yes** | Main check logic; call `notify` to report |
| `#fix(problem)` | No | Auto-fix a problem; raise `NoFix` to skip |

### Helper Methods Available in Checks

| Method | Returns | Description |
|--------|---------|-------------|
| `tokens` | `Array<Token>` | Full token stream |
| `manifest_lines` | `Array<String>` | Source lines |
| `semantic_tokens` | `Array<Token>` | Non-formatting tokens only |
| `resource_indexes` | `Array<Hash>` | Resource body locations |
| `class_indexes` | `Array<Hash>` | Class definition locations |
| `defined_type_indexes` | `Array<Hash>` | Defined type locations |
| `node_indexes` | `Array<Hash>` | Node definition locations |
| `title_tokens` | `Array<Token>` | Resource title tokens |
| `fullpath` | `String` | Full file path |
| `filename` | `String` | Base filename |
| `notify(kind, details)` | — | Report a problem |

### `notify` Parameters

```ruby
notify :warning,    # or :error
  message: 'description of problem',
  line:    42,
  column:  5
```

---

## Class: OpenvoxLint::Configuration

### Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `log_format` | `String` | `'text'` | Output format |
| `with_filename` | `Boolean` | `true` | Show filename in output |
| `fail_on_warnings` | `Boolean` | `false` | Exit 1 on warnings |
| `fix` | `Boolean` | `false` | Auto-fix mode |
| `only_checks` | `Array<Symbol>` | `[]` | Run only these checks |
| `disabled_checks` | `Array<Symbol>` | `[]` | Skip these checks |
| `ignore_paths` | `Array<String>` | vendor, pkg, spec | Glob patterns to ignore |
| `config_file` | `String` | `.openvox-lint.rc` | RC file path |
| `relative` | `Boolean` | `false` | Use relative paths |
| `column` | `Boolean` | `true` | Show column numbers |
| `custom_log_format` | `String\|nil` | `nil` | Custom format string |

### Methods

| Method | Description |
|--------|-------------|
| `#load_from_rc(path)` | Load config from an RC file |
| `#check_enabled?(name)` | Is a check enabled? |

---

## Class: OpenvoxLint::Linter

### Usage

```ruby
linter = OpenvoxLint::Linter.new
linter.run('manifests/')
linter.problems    # => Array of problem hashes
linter.errors?     # => true/false
linter.exit_code   # => 0 or 1
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `#run(*paths)` | — | Lint files/directories |
| `#problems` | `Array<Hash>` | All detected problems |
| `#file_count` | `Integer` | Number of files checked |
| `#errors?` | `Boolean` | Any errors found? |
| `#warnings?` | `Boolean` | Any warnings found? |
| `#exit_code` | `Integer` | 0=clean, 1=problems |

---

## Class: OpenvoxLint::Report

### Usage

```ruby
report = OpenvoxLint::Report.new(config)
report.format(problems)           # to $stdout
report.format(problems, io: file) # to file
```

### Supported Formats

| Format | Flag | Description |
|--------|------|-------------|
| `text` | `-f text` (default) | `path:line:col: KIND: check: message` |
| `json` | `-f json` | JSON array |
| `csv` | `-f csv` | CSV with headers |
| `github` | `-f github` | GitHub Actions annotations |
| `codeclimate` | `-f codeclimate` | Code Climate JSON |
| `custom` | `--log-format` | User-defined format string |

---

## Complete Check Reference

### Whitespace & Alignment Checks

#### `space_before_arrow` (WARNING)

Controls spacing before `=>` (hash rocket) in resource parameter blocks.
In Puppet manifests, it is standard practice to vertically align `=>`
arrows within a resource body.  This means the parameter with the
**longest key name** has exactly one space before `=>`, and all shorter
keys have additional padding spaces to bring their `=>` into alignment.

The check groups `=>` tokens by line proximity.  Within each group it
identifies the longest key and only flags that key if it has more than
one space before `=>`.  Shorter keys are permitted extra spaces for
alignment.  A single-parameter resource with extra space before `=>`
is always flagged (nothing to align with).

**Good — properly aligned (no warnings):**
```puppet
file { '/etc/nginx/nginx.conf':
  ensure  => file,
  content => template('nginx/nginx.conf.erb'),
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
}
```

Here `content` is the longest key (7 characters).  It has a single space
before `=>`.  All other keys (`ensure`, `owner`, `group`, `mode`) have
padding to align their `=>` with `content =>`'s column.  No warnings.

**Bad — longest key has extra space:**
```puppet
file { '/tmp/foo':
  ensure  => present,
  mode    => '0644',
  owner   => 'root',
}
```

`ensure` is the longest key (6 chars) but has 2 spaces before `=>`.
The check flags `ensure` only; `mode` and `owner` padding is fine.

**Bad — single parameter with extra space:**
```puppet
package { 'httpd':
  ensure   => installed,
}
```

Only one parameter — no alignment context — the 3 extra spaces are
flagged.

---

### Puppet 8 / OpenVox 8 Migration Checks

These are the most important checks for users upgrading from Puppet 7 or
migrating to OpenVox.

#### `legacy_facts` (WARNING)

Legacy (unstructured) top-scope facts are excluded by default in Puppet 8 /
OpenVox 8.  Variables like `$osfamily`, `$fqdn`, `$ipaddress`, and
`$operatingsystem` must be replaced with structured facts.

**Bad:**
```puppet
if $osfamily == 'RedHat' { }
```

**Good:**
```puppet
if $facts['os']['family'] == 'RedHat' { }
```

Covers 80+ legacy fact names.

#### `top_scope_facts` (WARNING)

Top-scope fact variables (`$::hostname`) should use the `$facts` hash.

**Bad:**
```puppet
$hostname = $::hostname
```

**Good:**
```puppet
$hostname = $facts['networking']['hostname']
```

#### `hiera3_function` (ERROR)

Hiera 3 functions are removed in Puppet 8. This is an error, not a warning.

**Bad:**
```puppet
$val = hiera('mykey')
$hash = hiera_hash('myhash')
```

**Good:**
```puppet
$val = lookup('mykey')
$hash = lookup('myhash', Hash, 'hash')
```

#### `import_statement` (ERROR)

The `import` keyword was removed in Puppet 4.

**Bad:**
```puppet
import 'foo'
```

**Good:**
Use module autoloading.

---

## Puppet 8 / OpenVox 8 Language Context

openvox-lint is designed with full awareness of the Puppet 8 / OpenVox 8
language changes:

### Changes from Puppet 7

| Change | Impact | openvox-lint Check |
|--------|--------|-------------------|
| Strict mode enabled by default | Undefined vars → errors | (runtime) |
| Legacy facts excluded | `$osfamily` etc. unavailable | `legacy_facts` |
| Top-scope facts deprecated | `$::fact` pattern obsolete | `top_scope_facts` |
| Hiera 3 removed | `hiera()` functions gone | `hiera3_function` |
| PSON removed | Binary serialization changed | (runtime) |
| String literals frozen | Immutable strings | (runtime) |
| Ruby 3.2 required | API changes | (gemspec) |
| `Deferred` lazy evaluation | Resource ordering matters | (runtime) |
| `Sensitive` auto-protection | Deferred functions protected | (runtime) |

### OpenVox Compatibility

OpenVox 8.x is a **fully compatible fork** of Puppet 8.x:
- **Identical language syntax** — no changes to the Puppet DSL
- **Identical module compatibility** — all Puppet Forge modules work
- **Different package names** — `openvox-agent` replaces `puppet-agent`
- **Same configuration paths** — `/etc/puppetlabs/`
- **Community maintained** by Vox Pupuli

openvox-lint works identically with both OpenVox and Puppet manifests.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | No errors (warnings allowed unless `--fail-on-warnings`) |
| `1` | Errors found, or warnings with `--fail-on-warnings` |

---

## Plugin Development

### Creating a Check Plugin

```ruby
# my_check.rb
OpenvoxLint.new_check(:my_check) do
  def check
    tokens.each do |tok|
      if tok.type == :NAME && tok.value == 'bad_thing'
        notify :warning,
          message: 'found bad_thing',
          line: tok.line,
          column: tok.column
      end
    end
  end

  # Optional: auto-fix
  def fix(problem)
    # Modify tokens in-place
    raise OpenvoxLint::NoFix  # if can't fix
  end
end
```

### Distributing as a Gem

```ruby
# my-openvox-lint-check.gemspec
Gem::Specification.new do |s|
  s.name = 'openvox-lint-my_check'
  s.add_runtime_dependency 'openvox-lint', '~> 1.0'
end
```

Place the check file in `lib/openvox-lint/plugins/checks/my_check.rb`.

---

## File Inventory

| File | Lines | Description |
|------|-------|-------------|
| `bin/openvox-lint` | 7 | CLI entry point |
| `lib/openvox-lint.rb` | 47 | Main module, auto-loader |
| `lib/openvox-lint/version.rb` | 5 | Version constant |
| `lib/openvox-lint/configuration.rb` | 59 | Configuration management |
| `lib/openvox-lint/token.rb` | 38 | Token data structure |
| `lib/openvox-lint/lexer.rb` | 342 | Puppet/OpenVox lexer |
| `lib/openvox-lint/check_plugin.rb` | 147 | Base check class |
| `lib/openvox-lint/checks.rb` | 46 | Check runner |
| `lib/openvox-lint/report.rb` | 86 | Output formatters |
| `lib/openvox-lint/linter.rb` | 72 | File orchestrator |
| `lib/openvox-lint/cli.rb` | 87 | CLI parser |
| `lib/openvox-lint/plugins/checks/*.rb` | 38 files | Check plugins |
| `spec/spec_helper.rb` | 41 | Test helper |
| `spec/unit/lexer_spec.rb` | 85 | Lexer tests |
| `spec/unit/checks_spec.rb` | 142 | Check tests |
