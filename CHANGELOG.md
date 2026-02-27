# Changelog

All notable changes to openvox-lint will be documented in this file.

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
  - **References**: `leading_zero`, `resource_reference_without_title_capital`, `relative_classname_inclusion`, `autoloader_layout`
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
