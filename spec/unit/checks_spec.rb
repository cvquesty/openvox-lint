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
end
