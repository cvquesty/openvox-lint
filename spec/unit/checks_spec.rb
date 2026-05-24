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

    it 'does not flag locally declared variables in class parameters' do
      code = "class foo($osfamily) { notify { $osfamily: } }\n"
      problems = lint(code, checks: %w[legacy_facts])
      expect(problems).to be_empty
    end

    it 'does not flag variables in lambda blocks' do
      code = "$data.each |$osfamily| { notify { $osfamily: } }\n"
      problems = lint(code, checks: %w[legacy_facts])
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
      problems = lint("case $foo { 'a' => 1 }", checks: %w[case_without_default])
      expect(problems.size).to eq(1)
    end
  end

  describe ':star_comments' do
    it 'flags star comments' do
      problems = lint("#***************\n", checks: %w[star_comments])
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
  end

  describe ':unquoted_resource_title' do
    it 'does not falsely report resource types inside class/define bodies as unquoted titles' do
      # Regression test for the exact bug reported with banner.pp
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
      fixed = manifest_lines.join("\n") + "\n"
      [checker.problems, fixed]
    end

    it 'trailing_whitespace removes trailing whitespace' do
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
end
