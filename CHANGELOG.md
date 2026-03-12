# Changelog

All notable changes to openvox-lint will be documented in this file.

## [1.2.0] - 2026-03-12

### Fixed

- **`legacy_facts` false positives on local variables** — The check no longer
  flags class/define parameters or lambda block parameters that happen to share
  names with legacy facts (`$path`, `$type`, `$os`, etc.). Previously, any
  variable with a legacy fact name would trigger a warning, even when it was
  clearly a locally-scoped parameter with no relation to facts.

  **Contributed by [@hbro](https://github.com/hbro) (Hans Broeckx)** in
  [PR #1](https://github.com/cvquesty/openvox-lint/pull/1). This is openvox-lint's
  first community contribution! 🎉

  The fix adds a pre-scan phase that collects all locally declared variable names
  from:
  - Class and defined type parameter lists
  - Lambda block parameter lists (`|$var|`)

  These local variables are then excluded from the legacy fact name check,
  eliminating false positives while still correctly detecting actual legacy
  fact references.

### Contributors

- **Hans Broeckx ([@hbro](https://github.com/hbro))** — First community contributor!

## [1.1.1] - 2026-03-12

### Documentation

- **Comprehensive technical documentation rewrite**: Complete overhaul of
  [DOCUMENTATION.md](DOCUMENTATION.md) with:
  - Full API reference for all classes (Token, Lexer, CheckPlugin, Configuration,
    Linter, Report)
  - Complete documentation for all 37 checks with good/bad code examples
  - Organized checks by category (Whitespace, Strings, Variables, Resources, etc.)
  - Comprehensive token types reference
  - Plugin development guide with examples
  - Migration guide from puppet-lint

- **New CONTRIBUTING.md**: Added comprehensive contributor guide with:
  - Development setup instructions
  - Project structure documentation
  - Testing instructions
  - Check plugin writing guide
  - Coding standards
  - Release process

- **Hiera 3 → Hiera 5 clarification**: Updated all documentation to clarify
  that Hiera 3 is fully deprecated and only Hiera 5 is supported in Puppet 8 /
  OpenVox 8. The `hiera3_function` check now explicitly references "Hiera 5
  lookup()" as the replacement.

### Changed

- **`hiera3_function` error message**: Improved to explicitly mention Hiera 5:
  "deprecated Hiera 3 function 'hiera()' — use Hiera 5 lookup() instead"

## [1.1.0] - 2026-03-05

### Removed

- **`relative_classname_inclusion` check**: This check warned when
  `include`, `require`, or `contain` statements used relative (non-`::`)
  multi-segment class names instead of fully qualified ones.  Since
  Puppet 4, the Puppet language resolver correctly handles relative class
  name resolution, making relative class name inclusion safe and the
  check obsolete.  The check has been removed entirely.  Users who had
  disabled it via `--no-relative_classname_inclusion-check` or
  `.openvox-lint.rc` can safely remove those overrides.

### Changed

- **Check count**: 38 → 37 built-in checks.

## [1.0.8] - 2026-03-04

### Fixed

- **CLI: stale configuration on re-invocation**: The global configuration
  singleton is now reset at the start of every `CLI#run`.  Repeated
  invocations in the same Ruby process (Vim plugins, guard, Rake loops)
  no longer inherit stale `disabled_checks`, `only_checks`, or other
  settings from a previous run.

- **CLI: `--config` flag ignored when local RC exists**: The `-c` /
  `--config FILE` flag now takes strict priority.  Previously a local
  `.openvox-lint.rc` would shadow an explicit `--config` path.

- **lint:ignore / lint:endignore block suppression**: Block-style ignore
  comments now work as documented.  `# lint:ignore:check_name` on its
  own line opens a suppression block; `# lint:endignore` closes it.
  All problems on lines between the two comments are suppressed for
  the named checks.  Inline ignore comments (on the same line as code)
  continue to work as before.

- **ignore-paths glob matching with relative/absolute prefixes**: The
  `--ignore-paths` glob patterns (and the defaults `vendor/**/*.pp`,
  `pkg/**/*.pp`, `spec/**/*.pp`) now match correctly regardless of
  whether the file was discovered via `./vendor/foo.pp`, `vendor/foo.pp`,
  or an absolute path.

- **trailing_comma false positives on non-resource braces**: The
  `trailing_comma` check now only fires inside resource bodies
  (`name { ... }`).  It no longer produces false positives on `if`,
  `unless`, `case`, class bodies, or other brace-delimited contexts
  where a trailing comma is not expected.

- **arrow_alignment / space_before_arrow contradictory warnings**: The
  `arrow_alignment` check now defers to `space_before_arrow` when the
  misalignment in a group is caused by the longest key having extra
  whitespace.  This eliminates contradictory double-warnings on the
  same resource block.

- **Unterminated strings and regex now reported as errors**: The lexer
  now raises `OpenvoxLint::Error` when a single-quoted string,
  double-quoted string, or regex literal is not terminated before
  end-of-file.  Previously the lexer silently produced a truncated
  token covering the rest of the file, leading to wrong lint results.

- **Multi-line string tokens now report correct line number**: String
  tokens that span multiple lines now record the **starting** line
  number, not the ending line.  Checks that flag these tokens now
  point to the correct source location.

- **variables_not_enclosed mixed variable handling**: Strings containing
  both enclosed (`${bar}`) and unenclosed (`$foo`) variables now
  correctly flag only the unenclosed references.  Previously the
  entire string was skipped if any `${...}` pattern was present.

- **resource_reference_without_title_capital expanded allowlist**: The
  function allowlist that prevents false positives on `name[...]`
  patterns now covers 40+ Puppet built-in and stdlib functions
  (`each`, `map`, `filter`, `reduce`, `lookup`, `dig`, etc.),
  not just the original 5.

### Changed

- **duplicate_params / parameter_order: removed dead code**: Both checks
  contained `.formatting?` guard clauses that could never trigger
  because they operate on pre-filtered semantic tokens.  The dead code
  has been removed for clarity.

- **Check registry duplicate warning**: `OpenvoxLint.new_check` now
  emits a warning to stderr (when `OPENVOX_LINT_DEBUG` is set) if a
  check name that is already registered is overwritten.  This helps
  detect accidental name collisions in custom check plugins.

- **Gemfile cleaned up**: Removed duplicate gem declarations that were
  listed in both the Gemfile `group` block and the gemspec
  `add_development_dependency` entries.

## [1.0.7] - 2026-02-25

### Changed
- **Ruby compatibility**: Lowered minimum Ruby version to **2.5.0** (from 2.6.0). Covers every currently-supported enterprise platform out of the box — RHEL 8 / Rocky 8 (Ruby 2.5, supported until 2029), SLES 15 (Ruby 2.5), macOS system Ruby (2.6), Ubuntu 20.04+ (2.7+), and all modern Ruby 3.x releases. No code changes required — all syntax has been 2.5-compatible since 1.0.0.
- **RubyGems.org release**: First official publication to RubyGems.org for `gem install openvox-lint`.

## [1.0.6] - 2026-02-25

### Changed
- **Ruby compatibility**: Lowered minimum Ruby version from 3.1.0 to 2.6.0 in the gemspec. The codebase uses no Ruby 3.x-specific features — all syntax is compatible with Ruby 2.6+ including macOS system Ruby. This broadens compatibility with systems that ship older Ruby versions without requiring a separate Ruby installation.
- **Documentation**: Updated prerequisites, badges, and comparison table to reflect Ruby ≥ 2.6 support.

## [1.0.5] - 2026-02-25

### Changed
- **Documentation**: Comprehensive README rewrite with status badges, detailed "Enabling and Disabling Checks" guide (command-line flags, --only-checks, configuration files, inline suppression), "Updating" instructions (gem, bundler, source), and "Uninstalling" instructions (gem removal, config cleanup).

## [1.0.3] - 2026-02-09

### Fixed

- **double_quoted_strings**: No longer flags double-quoted strings that
  contain nested single-quote characters (e.g. `"it's running"`,
  `"use 'ensure' as first parameter"`).  Double quotes are the correct
  choice when the string body contains literal single quotes, and this
  is now recognised and skipped.

## [1.0.2] - 2026-02-09

### Fixed

- **duplicate_params**: No longer generates false positives when multiple
  resource blocks inside a class or defined type share the same parameter
  names (e.g. `command`, `path`, `onlyif` across separate `exec` blocks).
  The underlying `compute_resource_indexes` helper now scopes each
  resource's `param_tokens` to brace depth 1, so tokens belonging to
  nested resource declarations are excluded.

## [1.0.1] - 2026-02-09

### Fixed

- **space_before_arrow**: No longer generates false positives on properly
  aligned `=>` arrows.  In a multi-parameter resource block, only the
  parameter with the longest key name is expected to have a single space
  before `=>`.  Shorter keys may have additional padding spaces for
  alignment and these are no longer flagged.

## [1.0.0] - 2025-02-09

### Added

- **Core Engine**
  - Complete Puppet / OpenVox manifest lexer/tokenizer
  - Token-based check plugin architecture with `OpenvoxLint.new_check` DSL
  - Doubly-linked token list for efficient navigation
  - Support for all Puppet 8 / OpenVox 8.x language constructs
  - Heredoc, EPP tag, regex, and string interpolation tokenization

- **38 Built-in Checks**
  - **Whitespace**: `trailing_whitespace`, `hard_tabs`, `line_length`, `space_before_arrow`, `strict_indent`
  - **Alignment**: `arrow_alignment`
  - **Strings**: `double_quoted_strings`, `only_variable_string`, `single_quote_string_with_variables`, `variables_not_enclosed`, `quoted_booleans`
  - **Variables**: `variable_is_lowercase`, `variable_contains_dash`
  - **Resources**: `ensure_first_param`, `ensure_not_symlink_target`, `file_mode`, `unquoted_file_mode`, `unquoted_resource_title`, `duplicate_params`, `trailing_comma`
  - **Classes**: `documentation`, `nested_classes_or_defines`, `parameter_order`, `class_inherits_params`, `inherits_across_namespaces`
  - **Conditionals**: `case_without_default`, `selector_inside_resource`
  - **References**: `leading_zero`, `resource_reference_without_title_capital`, `autoloader_layout`
  - **Comments**: `star_comments`
  - **URLs**: `puppet_url_without_modules`
  - **Nodes**: `node_name_unquoted`
  - **Puppet 8 / OpenVox 8** ⭐: `legacy_facts`, `top_scope_facts`, `hiera3_function`, `import_statement`

- **Output Formats**
  - Text (default), JSON, CSV, GitHub Actions, Code Climate, Custom

- **CLI Features**
  - `--fix` auto-fix support
  - `--fail-on-warnings` for strict CI
  - `--only-checks` and `--no-<check>-check` granular control
  - `--list-checks` to enumerate all checks
  - `.openvox-lint.rc` configuration file support
  - `# lint:ignore:check_name` inline suppression

- **Integration**
  - vim-openvox plugin compatibility
  - GitHub Actions workflow support
  - Rake task integration
  - Pre-commit hook support

### Compatibility

- OpenVox 8.x (community fork of Puppet)
- Puppet 8.x
- Puppet 7.x (with deprecation warnings)
- Ruby ≥ 3.1.0
