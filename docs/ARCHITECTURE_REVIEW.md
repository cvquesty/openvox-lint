# Architecture Review — openvox-lint

**Subject:** tip `2facd76` plus this PR's remediations, rebased onto `development` after #6 (Ruby/CI matrix), #7 (fail-closed paths), #9 (release checklist), and #12 (RC/`--fix`/GHA/symlink).
**Default branch:** `development`
**Review date:** 2026-09-18 (rebase note same day)
**Scope:** Architecture-owned findings only. Sibling security/systems work is now on `development` and is not re-litigated here. Remaining sibling-owned drift (`--relative`, issues #3 and #5, fail-closed unknown `-f`) is cited only as context.

Severity scale:

| Level | Meaning |
|-------|---------|
| High | Users or integrators will be misled or lose work if they trust the current contract |
| Medium | Dead API, silent overwrite, or documented behaviour that does not match code |
| Low | Comment / changelog / marketing overclaim with no runtime effect |
| Info | Structural observation; no defect |

Each finding lists **evidence** (path + symbol) and a **recommendation**. Items marked **Remediated here** were fixed in this architecture PR.

---

## 1. Lexer / token / check plugin model

openvox-lint is a single-process, token-stream linter with no AST and no runtime gems.

```
CLI / API  →  Linter  →  Lexer  →  Token[]  →  Checks  →  Report
                 │                      │
                 └──── Configuration ───┘
```

| Stage | Symbol | Role |
|-------|--------|------|
| CLI | `OpenvoxLint::CLI#run` in `lib/openvox-lint/cli.rb` | Resets the configuration singleton, parses flags, loads one RC file, constructs `Linter` |
| Orchestrator | `OpenvoxLint::Linter#lint_file` in `lib/openvox-lint/linter.rb` | `File.read` → `Lexer.new` → `Checks#run` → optional `File.write` of mutated `manifest_lines` |
| Lexer | `OpenvoxLint::Lexer#tokenise` in `lib/openvox-lint/lexer.rb` | Hand-written scanner; emits `Token` objects and links `prev_token` / `next_token` |
| Token | `OpenvoxLint::Token` in `lib/openvox-lint/token.rb` | `type`, `value`, `line`, `column`, `formatting?` |
| Registry | `OpenvoxLint.new_check` / `.checks` in `lib/openvox-lint.rb` | `Class.new(CheckPlugin, &block)` stored in a process-global Hash |
| Runner | `OpenvoxLint::Checks#run` in `lib/openvox-lint/checks.rb` | Instantiates each enabled check, collects problems, optionally calls `#fix_problems` |
| Plugin base | `OpenvoxLint::CheckPlugin` in `lib/openvox-lint/check_plugin.rb` | `#check`, `#fix`, `notify`, `semantic_tokens`, `resource_indexes`, `class_indexes`, `defined_type_indexes`, `node_indexes`, `title_tokens` |
| Report | `OpenvoxLint::Report#format` in `lib/openvox-lint/report.rb` | text / json / csv / github / codeclimate / custom |

**Built-in load boundary.** After the module is defined, `lib/openvox-lint.rb` does:

```ruby
Dir[File.join(__dir__, 'openvox-lint', 'plugins', 'checks', '*.rb')].sort.each do |f|
  require f
end
```

That glob is this gem's `__dir__` only. There is no second pass over `$LOAD_PATH`, `Gem::Specification`, or a CLI `--load` path.

**Fix model.** `CheckPlugin#fix` defaults to `raise OpenvoxLint::NoFix`. Five plugins override it and mutate `@manifest_lines` (chomped copies from the lexer): `trailing_whitespace`, `hard_tabs`, `quoted_booleans`, `double_quoted_strings`, `single_quote_string_with_variables`. `Linter#lint_file` then joins those lines and writes the file. This is intentionally lighter than puppet-lint's token-rewriting `PuppetLint::Data` singleton (`UPDATE_SUMMARY.md`).

### F1. Lexer comment claimed EPP / dedicated type tokens — **Low** — **Remediated here**

- **Evidence:** `OpenvoxLint::Lexer` class comment in `lib/openvox-lint/lexer.rb` previously said the lexer recognised "heredocs, EPP tags, Deferred/Sensitive types, type aliases". `Lexer#tokenise` has no `<%` / `%>` branch; `<` is `SINGLE_CHAR[:LESSTHAN]`. `Deferred` / `Sensitive` / `Type` become `:NAME` or `:CLASSREF` via `scan_name`. `CHANGELOG.md` `[1.0.0]` repeated "EPP tag … tokenization". `DOCUMENTATION.md` "Supported Constructs" was already honest (no EPP).
- **Recommendation:** Keep the class comment scoped to `.pp` constructs. Do not add an EPP scanner unless `.epp` becomes a first-class target (needs tag tokens and EPP parameter lists). Sibling issue #5 owns heredoc terminator behaviour.

### F2. Helpers are depth-aware and worth keeping — **Info**

- **Evidence:** `CheckPlugin#compute_resource_indexes` walks `semantic_tokens`, skips `class`/`define`/`node` `NAME {` bodies, and collects `param_tokens` only at brace depth 1. `find_keyword_indexes` and `compute_title_tokens` share the same skip. Regression coverage: `spec/unit/checks_spec.rb` `:unquoted_resource_title`.
- **Recommendation:** Keep this lighter helper model. Do not port `PuppetLint::Data` unless `#fix` needs token-list rewriting.

---

## 2. Dead APIs

### F3. `respond_to?(:fix_problems)` guard — **Low** — **Remediated here**

- **Evidence:** `Checks#run` in `lib/openvox-lint/checks.rb` called `plugin.fix_problems if @configuration.fix && plugin.respond_to?(:fix_problems)`. `CheckPlugin#fix_problems` is defined on the base class (`lib/openvox-lint/check_plugin.rb`). Every registered check is `Class.new(CheckPlugin, &block)`. The guard never skipped.
- **Recommendation:** Call `#fix_problems` whenever `configuration.fix` is true. `#fix` still raises `NoFix` for unimplemented cases.

### F4. `formatting?` walk inside `compute_resource_indexes` — **Low** — **Remediated here**

- **Evidence:** `compute_resource_indexes` assigned `sem = semantic_tokens`, and `semantic_tokens` is `tokens.reject(&:formatting?)`. The backward walk then did `break unless t.formatting?`, which is always false on `sem`. The loop could only inspect `sem[i - 1]`. The same dead pattern was already removed from `duplicate_params` / `parameter_order` (`CHANGELOG.md` `[1.0.8]`).
- **Recommendation:** Test the previous semantic token only. Do not remove `Token#formatting?` itself — `Checks#inline_ignore?` and several checks (`documentation`, `leading_zero`, `file_mode`, …) still walk the raw `tokens` stream.

### F5. Duplicate `new_check` warning hidden behind `OPENVOX_LINT_DEBUG` — **Medium** — **Remediated here**

- **Evidence:** `OpenvoxLint.new_check` in `lib/openvox-lint.rb` overwrote `checks[name]` and printed a warning only when `ENV['OPENVOX_LINT_DEBUG']` was set. `CHANGELOG.md` `[1.0.8]` documented that debug gate. A custom file that reused `:trailing_whitespace` would silently replace the built-in check.
- **Recommendation:** Always warn on stderr. Keep overwrite (failing would break the spec helper, which `load`s check files into an already-populated registry). A future `--fail-on-duplicate-check` flag is optional.

### F6. `--relative` / `Configuration#relative` is stored and never read — **Medium** — **Deferred (systems sibling)**

- **Evidence:** `CLI#parse_options` sets `@config.relative = true` (`lib/openvox-lint/cli.rb`). `Configuration::DEFAULTS` and `attr_accessor :relative` exist (`lib/openvox-lint/configuration.rb`). `Report#format_text` / `#format_github` / `#serialise` emit `p[:path]` as the `fullpath` passed into `Checks` (`lib/openvox-lint/linter.rb`). No reader of `@config.relative`. Documented in README usage, DOCUMENTATION configuration table.
- **Recommendation:** Sibling owns implement-or-remove. Do not change path logic here.

---

## 3. puppet-lint comparison honesty

README and DOCUMENTATION tables previously described puppet-lint 5.x as if it were a frozen, plugin-dependent archive. puppet-lint `main` (fetched 2026-09-18) is maintained.

| Previous claim | Evidence it is stale | Remediation |
|----------------|----------------------|-------------|
| GitHub Actions output: **No** | puppet-lint README: `--sarif`, [puppet-lint-action](https://github.com/marketplace/actions/puppet-lint-action); MegaLinter help text lists `--sarif`. Env-based `::` annotations exist in the ecosystem (voxpupuli/onceover-codequality#59). | Table now says puppet-lint has SARIF / action / env annotations; openvox-lint has `-f github`. |
| Code Climate output: **No** | puppet-lint README: `--codeclimate-report-file` and `CODECLIMATE_REPORT_FILE`. | Table now credits both. |
| Legacy / top-scope facts: **Via plugin** | `lib/puppet-lint/plugins/legacy_facts/legacy_facts.rb` and `top_scope_facts/` ship **in** puppet-lint; README documents YAML legacy-fact checks. | Table now says built-in on both sides. |
| Built-in checks: **~25** | Core set has grown; count is no longer a stable differentiator. | Table describes the core set plus fact checks instead of a guessed number. |
| Plugin system: **Yes (compatible)** | puppet-lint has `--load`, `--load-from-puppet`, and `PuppetLint::Plugins.load_from_gems` (`lib/puppet-lint/plugins.rb` walks other gems' `lib/puppet-lint/plugins/**/*.rb`). openvox-lint has none of those. The `new_check` / `notify` names look similar; loading and `#fix` do not. | Tables now say require-your-file only / not drop-in compatible. |
| `--fix`: unqualified **Yes** | puppet-lint rewrites tokens for many core checks. openvox-lint has five line-based `#fix` methods (grep `def fix` under `lib/openvox-lint/plugins/checks/`). | Tables list the five names. |

Still-valid differentiators (with current evidence):

- **Hiera 3 functions** and **`import`** as built-in errors — not in puppet-lint's published core check list.
- **OpenVox** style-guide targeting and `vim-openvox` as the default backend.
- **Native CSV** (`Report#format_csv`) — puppet-lint help lists json/sarif/codeclimate/log-format, not CSV.
- **Ruby floor** as declared here (`>= 2.5.0` in `openvox-lint.gemspec`). Sibling owns whether that claim matches CI (`.github/workflows/ci.yml` matrices `3.1`/`3.2`/`3.3` only).

### F7. Comparison tables overclaimed vs current puppet-lint — **Medium** — **Remediated here**

- **Recommendation:** Keep the tables dated. Re-check puppet-lint `main` when cutting a release that touches marketing rows. Do not claim "drop-in replacement" in the gemspec without a loading story (the gemspec still says "Drop-in replacement for the archived puppet-lint"; puppet-lint is not archived). Softening that sentence further is optional follow-up.

---

## 4. Design drift vs README / DOCUMENTATION

### F8. Custom-plugin docs promised gem auto-discovery — **High** — **Remediated here**

- **Evidence:** README "Writing Custom Checks" said "Place in `lib/openvox-lint/plugins/checks/` and it will be auto-loaded." DOCUMENTATION "Distributing as a Gem" said the same for a third-party gem. The only loader is the `__dir__` glob in `lib/openvox-lint.rb`. `CLI#parse_options` has no `--load`. Contrast puppet-lint `PuppetLint::Plugins.load_from_gems`.
- **Recommendation (chosen):** Honest docs. A minimal `--load FILE` plus optional `Gem::Specification` walk is small but expands the CLI/security surface (path traversal, load-time code exec) and would collide with sibling CLI work. Revisit only with an explicit product request.

### F9. Check count and `--list-checks` copy — **Low** — **Remediated here** (count + list-checks)

- **Evidence:** README project tree said "38 built-in check plugins" while 37 files exist under `lib/openvox-lint/plugins/checks/` (`relative_classname_inclusion` removed in 1.1.0). README "Listing All Available Checks" claimed `--list-checks` prints severity and description; `CLI#list_checks` prints `✓`/`✗` and the name only. DOCUMENTATION header said "5+ checks" for `--fix`; five `#fix` methods exist.
- **Recommendation:** Keep the badge, tree, and `--fix` counts generated from the same inventory (37 files, 5 fixes). `--list-checks` copy now matches the CLI.

### F10. Documented `--relative`, unused — **Medium** — **Deferred (systems sibling)**

See F6. README usage and DOCUMENTATION `Configuration` table still describe the flag because the sibling may implement it.

### F11. Source-update docs pointed at `main` — **Low** — **Remediated here**

- **Evidence:** README "Updating / From Source" used `git pull origin main`. Default branch is `development`.
- **Recommendation:** Pull `development`.

---

## 5. Check extensibility

The in-tree DSL is adequate for contributors:

1. Add `lib/openvox-lint/plugins/checks/<name>.rb` calling `OpenvoxLint.new_check(:name)`.
2. Implement `#check` (required) and optionally `#fix`.
3. Use `notify :warning|:error, message:, line:, column:`.
4. Use helpers on `CheckPlugin` rather than re-scanning braces.

The **out-of-tree** story was the gap (F8). After this PR:

- Documented contract: `require 'openvox-lint'` then `require` your file.
- Duplicate names always warn (F5).
- A gem can wrap that require in its own entry point; openvox-lint will not search for it.

Remaining extensibility limits (not changed here):

| Limit | Evidence | Notes |
|-------|----------|-------|
| No `--load` | `CLI#parse_options` | Preferred honest docs over a new flag |
| No gem discovery | `lib/openvox-lint.rb` loader | Avoids loading every gem's `lib/openvox-lint/plugins/**` |
| `#fix` is line-based | five plugins mutate `@manifest_lines` | Structural fixes (e.g. `arrow_alignment`) stay future work |
| Registry is process-global | `OpenvoxLint.checks` | Spec helper must `instance_variable_set(:@checks, nil)` then `load` |
| No check metadata | `CLI#list_checks` | Name + enabled only; severity lives in docs |

---

## 6. Versioning / release notes

### F12. Semver process is documented; some historical notes overclaim — **Low** — **Partially remediated**

- **Evidence:** `CONTRIBUTING.md` "Releasing" requires bumping `OpenvoxLint::VERSION` (`lib/openvox-lint/version.rb`, currently `1.3.2`), `CHANGELOG.md`, and check counts. `[1.3.0]` says "All references now 1.3.1" (version-skid from the 1.3.0→1.3.1 republish; `UPDATE_SUMMARY.md` explains it). `[1.0.0]` claimed EPP tokenization (corrected in this PR). `[1.0.8]` documented the debug-gated duplicate warning (superseded by Unreleased).
- **Recommendation:** Add an `[Unreleased]` section for architecture work (done). Do not rewrite unrelated historical narrative. Combined with sibling `[Unreleased]` Security notes after rebase onto #9/#12.

### F13. Gemspec `--fix` "many checks" — **Low** — **Remediated here**

- **Evidence:** `openvox-lint.gemspec` `spec.description` said "Includes real --fix support for many checks." Only five plugins define `#fix`.
- **Recommendation:** Name the five. Leave the "drop-in replacement for the archived puppet-lint" sentence for a later marketing pass (F7).

---

## 7. Dependency boundaries

### F14. Runtime boundary is clean — **Info**

- **Evidence:** `openvox-lint.gemspec` has **no** `add_runtime_dependency`. Runtime requires: `optparse` (`cli.rb`), `json` (`report.rb`), plus core `File` / `Dir` / `Enumerable`. Dev-only: `rake`, `rspec`, `rubocop`. `Gemfile` is `gemspec` only. `Linter` / `Lexer` / `Checks` do not `require` Puppet, OpenVox, or psych/yaml.
- **Recommendation:** Keep the zero-runtime-gem boundary. A future gem-discovery loader (F8) would make RubyGems a functional dependency of check loading even if not declared — another reason honest docs were preferred.

### F15. Packaged files omitted `docs/` — **Low** — **Remediated here**

- **Evidence:** `spec.files` listed `lib/**/*`, `bin/*`, `LICENSE`, `README.md`, `CHANGELOG.md`, `DOCUMENTATION.md`. Architecture notes would not ship.
- **Recommendation:** Include `docs/**/*`.

---

## Remediations in this architecture PR

| Item | Change |
|------|--------|
| F1 | Narrowed `Lexer` class comment; corrected `[1.0.0]` EPP line |
| F3 | Dropped `respond_to?(:fix_problems)` |
| F4 | Replaced formatting walk with previous-semantic-token check |
| F5 | Duplicate `new_check` names always warn |
| F7 / F9 / F11 | Dated comparison tables; 38→37; `--list-checks` copy; `git pull origin development` |
| F8 | Honest README / DOCUMENTATION / CONTRIBUTING plugin docs |
| F13 / F15 | Gemspec `--fix` wording + `docs/**/*` |
| Report | This file |

---

## Sibling slices (do not re-implement here)

Landed on `development` before this rebase:

| Slice | PR | Topics now on `development` |
|-------|-----|-----------------------------|
| Security | #12 | RC cannot enable `--fix` (CLI `--[no-]fix`); no-follow / symlink `File.write`; `format_github` sanitization; CSV field escaping |
| Systems | #6 | Ruby 2.5-safe ranges + expanded CI matrix |
| Systems | #7 | Fail-closed `Linter#expand_files` on missing/empty inputs |
| Systems | #9 | Release checklist: git tag + gem + GitHub Release |

Still sibling-owned / open (not in this PR):

| Topic | Notes |
|-------|-------|
| `--relative` implement-or-remove | F6/F10 — flag still stored, never read |
| Issue #3 `variable_is_lowercase` | Not in this slice |
| Issue #5 heredoc lexer raise / junk-after-end-tag | Not in this slice |
| Fail-closed unknown `-f` | `Report#format` still falls through to text |

Related drift called out above but not owned here: F6/F10 (`--relative`), fail-closed unknown `-f`.
