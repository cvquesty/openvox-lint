# Changelog

All notable changes to openvox-lint will be documented in this file.

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
