# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Architecture contracts' do
  describe 'OpenvoxLint.new_check' do
    it 'always warns on stderr when a check name is already registered' do
      ENV.delete('OPENVOX_LINT_DEBUG')

      expect do
        OpenvoxLint.new_check(:trailing_whitespace) do
          def check; end
        end
      end.to output(/check 'trailing_whitespace' is already registered/).to_stderr

      expect(OpenvoxLint.checks).to have_key(:trailing_whitespace)
    end

    it 'still warns when OPENVOX_LINT_DEBUG is set' do
      ENV['OPENVOX_LINT_DEBUG'] = '1'
      expect do
        OpenvoxLint.new_check(:hard_tabs) do
          def check; end
        end
      end.to output(/already registered/).to_stderr
    ensure
      ENV.delete('OPENVOX_LINT_DEBUG')
    end
  end

  describe 'CheckPlugin#compute_resource_indexes' do
    def indexes_for(code)
      lexer = OpenvoxLint::Lexer.new(code)
      plugin = Class.new(OpenvoxLint::CheckPlugin) do
        def check; end
      end.new
      plugin.run(
        tokens: lexer.tokens,
        manifest_lines: lexer.manifest_lines,
        fullpath: 'test.pp',
      )
      plugin.send(:resource_indexes)
    end

    it 'does not treat class/define/node bodies as resources' do
      code = <<~PP
        class foo {
          file { '/tmp/x': ensure => present }
        }
        define bar {
          notify { 'n': }
        }
        node 'web' {
          service { 'sshd': }
        }
      PP
      types = indexes_for(code).map { |r| r[:type].value }
      expect(types).to contain_exactly('file', 'notify', 'service')
    end

    it 'still indexes a top-level resource' do
      types = indexes_for("file { '/tmp/x': }\n").map { |r| r[:type].value }
      expect(types).to eq(['file'])
    end
  end

  describe 'Lexer EPP honesty' do
    it 'does not emit dedicated EPP tokens for <% %> tags' do
      lexer = OpenvoxLint::Lexer.new('<% $foo %>')
      types = lexer.tokens.map(&:type)
      expect(types).not_to include(:EPP, :EPP_START, :EPP_END, :EPP_TAG)
      expect(types).to include(:LESSTHAN, :MODULO)
    end
  end
end
