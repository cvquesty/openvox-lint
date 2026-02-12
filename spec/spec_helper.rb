# frozen_string_literal: true

require_relative '../lib/openvox-lint'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random

  # Reset configuration between tests
  config.before(:each) do
    OpenvoxLint.instance_variable_set(:@configuration, nil)
    OpenvoxLint.instance_variable_set(:@checks, nil)
    # Re-load checks
    Dir[File.join(File.dirname(__FILE__), '..', 'lib', 'openvox-lint', 'plugins', 'checks', '*.rb')].sort.each do |f|
      load f
    end
  end
end

# Helper: lint a code snippet and return problems
def lint(code, checks: nil)
  config = OpenvoxLint::Configuration.new
  config.only_checks = checks.map(&:to_sym) if checks
  config.ignore_paths = []
  lexer = OpenvoxLint::Lexer.new(code)
  checker = OpenvoxLint::Checks.new(
    tokens: lexer.tokens,
    manifest_lines: lexer.manifest_lines,
    fullpath: 'test.pp',
    configuration: config,
  )
  checker.run
end
