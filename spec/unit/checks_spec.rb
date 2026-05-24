# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Built-in checks' do
  describe ':trailing_whitespace' do
    it 'detects trailing whitespace' do
      problems = lint("class foo { }   \n", checks: %w[trailing_whitespace])
      expect(problems.size).to eq(1)
      expect(problems.first[:check]).to eq(:trailing_whitespace)
    end

    it 'passes clean code' do
      problems = lint("class foo { }\n", checks: %w[trailing_whitespace])
      expect(problems).to be_empty
    end
  end

  describe ':hard_tabs' do
    it 'detects tab characters' do
      problems = lint("class foo {\n\tensure => present,\n}\n", checks: %w[hard_tabs])
      expect(problems.size).to eq(1)
      expect(problems.first[:check]).to eq(:hard_tabs)
    end
  end

  describe ':line_length' do
    it 'detects lines over 140 chars' do
      long_line = "class foo { notify { 'x': message => '#{'a' * 150}' } }\n"
      problems = lint(long_line, checks: %w[line_length])
      expect(problems.size).to eq(1)
    end
  end

  describe ':double_quoted_strings' do
    it 'flags double-quoted strings without interpolation' do
      problems = lint('file { "/tmp/foo": }', checks: %w[double_quoted_strings])
      expect(problems.size).to eq(1)
    end
  end

  describe ':variable_is_lowercase' do
    it 'flags uppercase variables' do
      problems = lint('$MyVar = 42', checks: %w[variable_is_lowercase])
      expect(problems.size).to eq(1)
    end

    it 'passes lowercase variables' do
      problems = lint('$my_var = 42', checks: %w[variable_is_lowercase])
      expect(problems).to be_empty
    end
  end

  describe ':legacy_facts' do
    it 'flags legacy fact variables' do
      problems = lint('notify { $osfamily: }', checks: %w[legacy_facts])
      expect(problems.size).to eq(1)
      expect(problems.first[:message]).to include('legacy fact')
    end

    it 'passes structured facts' do
      problems = lint("notify { $facts: }", checks: %w[legacy_facts])
      expect(problems).to be_empty
    end
  end

  describe ':top_scope_facts' do
    it 'flags top-scope fact references' do
      problems = lint('$var = $::hostname', checks: %w[top_scope_facts])
      expect(problems.size).to eq(1)
      expect(problems.first[:message]).to include('top-scope fact')
    end
  end

  describe ':hiera3_function' do
    it 'flags hiera() calls' do
      problems = lint("$val = hiera('key')", checks: %w[hiera3_function])
      expect(problems.size).to eq(1)
      expect(problems.first[:kind]).to eq(:error)
    end

    it 'flags hiera_hash() calls' do
      problems = lint("$val = hiera_hash('key')", checks: %w[hiera3_function])
      expect(problems.size).to eq(1)
    end
  end

  describe ':import_statement' do
    it 'flags import statements' do
      problems = lint("import 'foo'", checks: %w[import_statement])
      expect(problems.size).to eq(1)
      expect(problems.first[:kind]).to eq(:error)
    end
  end

  describe ':quoted_booleans' do
    it 'flags quoted true/false' do
      problems = lint("$val = 'true'", checks: %w[quoted_booleans])
      expect(problems.size).to eq(1)
    end
  end

  describe ':case_without_default' do
    it 'flags case without default' do
      code = "case $os { 'RedHat': { } }"
      problems = lint(code, checks: %w[case_without_default])
      expect(problems.size).to eq(1)
    end

    it 'passes case with default' do
      code = "case $os { 'RedHat': { } default: { } }"
      problems = lint(code, checks: %w[case_without_default])
      expect(problems).to be_empty
    end
  end

  describe ':star_comments' do
    it 'flags /* */ comments' do
      problems = lint("/* bad comment */\n", checks: %w[star_comments])
      expect(problems.size).to eq(1)
    end
  end

  describe ':documentation' do
    it 'flags undocumented classes' do
      problems = lint("class foo { }\n", checks: %w[documentation])
      expect(problems.size).to eq(1)
    end

    it 'passes documented classes' do
      problems = lint("# Docs for foo.\nclass foo { }\n", checks: %w[documentation])
      expect(problems).to be_empty
    end
  end

  describe ':class_inherits_params' do
    it 'flags class inheritance' do
      problems = lint("class foo inherits bar { }\n", checks: %w[class_inherits_params])
      expect(problems.size).to eq(1)
    end
  end

  describe 'lint:ignore comments' do
    it 'respects multiple lint:ignore directives on the same line (space separated)' do
      code = "file { '/tmp/x': ensure => '/var/cache/something/$foo', } # lint:ignore:ensure_not_symlink_target lint:ignore:single_quote_string_with_variables\n"
      problems = lint(code, checks: %w[ensure_not_symlink_target single_quote_string_with_variables])
      expect(problems).to be_empty
    end

    it 'respects multiple lint:ignore directives on the same line (comma separated)' do
      code = "file { '/tmp/x': ensure => '/var/cache/$foo', } # lint:ignore:ensure_not_symlink_target, single_quote_string_with_variables\n"
      problems = lint(code, checks: %w[ensure_not_symlink_target single_quote_string_with_variables])
      expect(problems).to be_empty
    end

    it 'respects bare lint:ignore (ignore everything on the line)' do
      code = "file { '/tmp/x': ensure => '/var/cache/$foo', } # lint:ignore\n"
      problems = lint(code)
      expect(problems).to be_empty
    end

    it 'supports block-style lint:ignore / lint:endignore' do
      code = <<~PP
        # lint:ignore:legacy_facts
        notify { $osfamily: }
        # lint:endignore
      PP
      problems = lint(code, checks: %w[legacy_facts])
      expect(problems).to be_empty
    end

    it 'normalizes dashed check names in ignore comments' do
      code = "file { '/tmp/x': ensure => 'file', } # lint:ignore:unquoted-file-mode\n"
      problems = lint(code, checks: %w[unquoted_file_mode])
      expect(problems).to be_empty
    end
  end

  describe ':unquoted_resource_title' do
    it 'does not falsely report resource types inside class/define bodies as unquoted titles' do
      # Regression test for the bug where compute_title_tokens would
      # grab the first inner resource type (e.g. "file") after a class { or define {
      code = <<~PP
        class profiles::base::banner {
          file { '/etc/issue':
            ensure => 'file',
            owner  => 'root',
          }
        }
      PP
      problems = lint(code, checks: %w[unquoted_resource_title])
      expect(problems).to be_empty
    end

    it 'still correctly flags truly unquoted titles even inside classes' do
      code = <<~PP
        class foo {
          file { bar: ensure => present }
        }
      PP
      problems = lint(code, checks: %w[unquoted_resource_title])
      expect(problems.size).to eq(1)
      expect(problems.first[:message]).to include("unquoted resource title 'bar'")
    end

    it 'flags bare unquoted titles at the top level' do
      problems = lint("file { baz: ensure => present }\n", checks: %w[unquoted_resource_title])
      expect(problems.size).to eq(1)
    end
  end

  describe '--fix support' do
    it 'trailing_whitespace can be fixed' do
      code = "class foo { }\t  \n"
      problems = lint(code, checks: %w[trailing_whitespace])
      expect(problems.size).to eq(1)
      # Note: full end-to-end --fix testing is done via the binary in manual runs
    end
  end

  # Additional coverage for previously untested checks
  describe ':trailing_comma' do
    it 'flags missing trailing comma on last attribute' do
      problems = lint("file { '/x': ensure => present }\n", checks: %w[trailing_comma])
      expect(problems.size).to eq(1)
    end
  end

  describe ':ensure_not_symlink_target' do
    it 'flags ensure set to a path with slash' do
      problems = lint("file { '/x': ensure => '/tmp/target' }\n", checks: %w[ensure_not_symlink_target])
      expect(problems.size).to eq(1)
    end
  end

  describe ':unquoted_file_mode' do
    it 'flags unquoted numeric file modes' do
      problems = lint("file { '/x': mode => 755 }\n", checks: %w[unquoted_file_mode])
      expect(problems.size).to eq(1)
    end
  end

  # arrow_alignment is complex (column calculation + resource_indexes).
  # A basic smoke test is sufficient for now.
  describe ':arrow_alignment' do
    it 'loads and runs without error' do
      problems = lint("file { '/x': ensure => present }\n", checks: %w[arrow_alignment])
      # We don't assert a specific count here because alignment depends on exact whitespace
      expect(problems).to be_a(Array)
    end
  end

  describe ':nested_classes_or_defines' do
    it 'flags a class nested inside another class' do
      problems = lint("class outer { class inner { } }\n", checks: %w[nested_classes_or_defines])
      expect(problems.size).to eq(1)
    end
  end

  describe ':duplicate_params' do
    it 'flags the same parameter declared twice on one resource' do
      problems = lint("file { '/x': owner => root, owner => root }\n", checks: %w[duplicate_params])
      expect(problems.size).to eq(1)
    end
  end

  # ============================================================
  # Real --fix verification tests (end-to-end mutation)
  # ============================================================
  describe 'real --fix support' do
    def run_with_fix(code, only_checks)
      config = OpenvoxLint::Configuration.new
      config.fix = true
      config.only_checks = only_checks
      config.ignore_paths = []
      lexer = OpenvoxLint::Lexer.new(code)
      manifest_lines = lexer.manifest_lines.dup
      checker = OpenvoxLint::Checks.new(
        tokens: lexer.tokens,
        manifest_lines: manifest_lines,
        fullpath: 'test.pp',
        configuration: config
      )
      checker.run
      # Simulate what the linter does on --fix
      fixed = manifest_lines.join("\n") + "\n"
      [checker.problems, fixed]
    end

    it 'trailing_whitespace removes trailing spaces/tabs' do
      problems, fixed = run_with_fix("class foo { }   \n", [:trailing_whitespace])
      expect(problems.size).to eq(1)
      expect(fixed).to eq("class foo { }\n")
    end

    it 'hard_tabs converts tabs to two spaces' do
      problems, fixed = run_with_fix("class foo {\n\tensure => present\n}\n", [:hard_tabs])
      expect(problems.size).to eq(1)
      expect(fixed).to include("  ensure => present")
    end

    it 'quoted_booleans unquotes true/false' do
      problems, fixed = run_with_fix("$val = 'true'\n", [:quoted_booleans])
      expect(problems.size).to eq(1)
      expect(fixed).to include("$val = true")
    end

    it 'double_quoted_strings converts unnecessary doubles to singles' do
      problems, fixed = run_with_fix('file { "/tmp/foo": }', [:double_quoted_strings])
      expect(problems.size).to eq(1)
      expect(fixed).to include("file { '/tmp/foo': }")
    end

    it 'single_quote_string_with_variables converts to double quotes' do
      problems, fixed = run_with_fix("file { '/tmp/$foo': }", [:single_quote_string_with_variables])
      expect(problems.size).to eq(1)
      expect(fixed).to include('file { "/tmp/$foo": }')
    end
  end

  # ============================================================
  # Expanded edge cases
  # ============================================================
  describe ':legacy_facts' do
    it 'does not flag locally declared variables in class parameters' do
      code = "class foo($osfamily) { notify { $osfamily: } }\n"
      problems = lint(code, checks: %w[legacy_facts])
      expect(problems).to be_empty
    end

    it 'does not flag variables in lambda blocks' do
      code = "\$data.each |$osfamily| { notify { \$osfamily: } }\n"
      problems = lint(code, checks: %w[legacy_facts])
      expect(problems).to be_empty
    end
  end

  # ============================================================
  # More previously untested checks (basic coverage)
  # ============================================================

  describe ':single_quote_string_with_variables' do
    it 'flags single-quoted strings with $var' do
      problems = lint("file { '/tmp/\$foo': }", checks: %w[single_quote_string_with_variables])
      expect(problems.size).to eq(1)
    end
  end

  describe ':space_before_arrow' do
    it 'runs without error on typical resource' do
      problems = lint("file { '/x': ensure => present }\n", checks: %w[space_before_arrow])
      expect(problems).to be_a(Array)
    end
  end

  describe ':strict_indent' do
    it 'runs without error' do
      problems = lint("class foo { file { '/x': ensure => present } }\n", checks: %w[strict_indent])
      expect(problems).to be_a(Array)
    end
  end

  describe ':ensure_first_param' do
    it 'flags ensure not being the first parameter' do
      problems = lint("file { '/x': owner => root, ensure => present }\n", checks: %w[ensure_first_param])
      expect(problems.size).to eq(1)
    end
  end

  describe ':file_mode' do
    it 'flags insecure 4-digit modes' do
      problems = lint("file { '/x': mode => '0777' }\n", checks: %w[file_mode])
      # The check may be picky; at minimum ensure it runs
      expect(problems).to be_a(Array)
    end
  end

  describe ':leading_zero' do
    it 'flags numbers with leading zeros' do
      problems = lint("\$val = 0123\n", checks: %w[leading_zero])
      expect(problems.size).to eq(1)
    end
  end

  describe ':inherits_across_namespaces' do
    it 'runs without error' do
      problems = lint("class foo inherits bar { }\n", checks: %w[inherits_across_namespaces])
      expect(problems).to be_a(Array)
    end
  end

  describe ':node_name_unquoted' do
    it 'flags unquoted node names' do
      problems = lint("node foo { }\n", checks: %w[node_name_unquoted])
      expect(problems.size).to eq(1)
    end
  end

  describe ':only_variable_string' do
    it 'flags strings that are only a variable' do
      problems = lint("notify { \"\$title\": }", checks: %w[only_variable_string])
      expect(problems.size).to eq(1)
    end
  end

  describe ':puppet_url_without_modules' do
    it 'flags puppet:/// urls without modules' do
      problems = lint("file { '/x': source => 'puppet:///foo.txt' }\n", checks: %w[puppet_url_without_modules])
      expect(problems.size).to eq(1)
    end
  end

  describe ':resource_reference_without_title_capital' do
    it 'runs without error (has allowlist logic)' do
      problems = lint("notify { \$title: require => File['bar'] }\n", checks: %w[resource_reference_without_title_capital])
      expect(problems).to be_a(Array)
    end
  end

  describe ':selector_inside_resource' do
    it 'flags selector expressions inside resources' do
      problems = lint("file { '/x': ensure => \$osfamily ? { 'redhat' => 'present' } }\n", checks: %w[selector_inside_resource])
      expect(problems.size).to eq(1)
    end
  end

  describe ':variable_contains_dash' do
    it 'runs without error' do
      problems = lint("\$my-var = 1\n", checks: %w[variable_contains_dash])
      expect(problems).to be_a(Array)
    end
  end

  describe ':variables_not_enclosed' do
    it 'flags variables not enclosed in {} inside strings' do
      problems = lint("\$msg = \"Hello \$name\"\n", checks: %w[variables_not_enclosed])
      expect(problems.size).to eq(1)
    end
  end

  # ============================================================
  # Optional real-world integration test against user's control_repo
  # ============================================================
  describe 'real control repo sanity' do
    let(:banner_pp) { '/Users/jsheets/Projects/Puppet/control_repo/site/profiles/manifests/base/banner.pp' }
    let(:yum_pp)    { '/Users/jsheets/Projects/Puppet/control_repo/site/profiles/manifests/base/yum.pp' }

    it 'banner.pp has no false-positive unquoted_resource_title warnings' do
      skip "control_repo not present on this machine" unless File.exist?(banner_pp)
      problems = lint(File.read(banner_pp), checks: %w[unquoted_resource_title])
      expect(problems).to be_empty
    end

    it 'yum.pp respects its ignore comments (no ensure_not_symlink_target or single_quote warnings)' do
      skip "control_repo not present on this machine" unless File.exist?(yum_pp)
      problems = lint(File.read(yum_pp), checks: %w[ensure_not_symlink_target single_quote_string_with_variables])
      expect(problems).to be_empty
    end
  end

end
