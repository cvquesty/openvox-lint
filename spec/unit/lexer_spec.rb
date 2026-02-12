# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpenvoxLint::Lexer do
  describe '#tokens' do
    it 'tokenises a simple class' do
      lexer = described_class.new("class foo {\n}\n")
      types = lexer.tokens.map(&:type)
      expect(types).to include(:CLASS, :NAME, :LBRACE, :RBRACE)
    end

    it 'recognises keywords' do
      code = 'if true { } else { } unless false { } case default define node'
      lexer = described_class.new(code)
      types = lexer.tokens.reject(&:formatting?).map(&:type)
      expect(types).to include(:IF, :TRUE, :ELSE, :UNLESS, :FALSE, :CASE, :DEFAULT, :DEFINE, :NODE)
    end

    it 'tokenises variables' do
      lexer = described_class.new('$foo $bar::baz $::topscope')
      vars = lexer.tokens.select { |t| t.type == :VARIABLE }
      expect(vars.map(&:value)).to eq(%w[$foo $bar::baz $::topscope])
    end

    it 'tokenises single-quoted strings' do
      lexer = described_class.new("'hello world'")
      strings = lexer.tokens.select { |t| t.type == :SSTRING }
      expect(strings.size).to eq(1)
    end

    it 'tokenises double-quoted strings' do
      lexer = described_class.new('"hello world"')
      strings = lexer.tokens.select { |t| t.type == :STRING }
      expect(strings.size).to eq(1)
    end

    it 'tokenises operators' do
      lexer = described_class.new('=> -> ~> == != =~ !~')
      types = lexer.tokens.reject(&:formatting?).map(&:type)
      expect(types).to include(:FARROW, :IN_EDGE, :IN_EDGE_SUB, :ISEQUAL, :NOTEQUAL, :MATCH, :NOMATCH)
    end

    it 'tokenises numbers' do
      lexer = described_class.new('42 0xFF 0755 3.14')
      nums = lexer.tokens.select { |t| t.type == :NUMBER }
      expect(nums.size).to eq(4)
    end

    it 'tokenises comments' do
      lexer = described_class.new("# this is a comment\n")
      comments = lexer.tokens.select { |t| t.type == :COMMENT }
      expect(comments.size).to eq(1)
    end

    it 'tokenises multi-line comments' do
      lexer = described_class.new("/* multi\nline */")
      ml = lexer.tokens.select { |t| t.type == :MLCOMMENT }
      expect(ml.size).to eq(1)
    end

    it 'tokenises class references' do
      lexer = described_class.new('String Integer File Notify')
      refs = lexer.tokens.select { |t| t.type == :CLASSREF }
      expect(refs.map(&:value)).to eq(%w[String Integer File Notify])
    end

    it 'links tokens in a doubly-linked list' do
      lexer = described_class.new("class foo { }")
      expect(lexer.tokens.first.prev_token).to be_nil
      expect(lexer.tokens.first.next_token).not_to be_nil
      expect(lexer.tokens.last.next_token).to be_nil
      expect(lexer.tokens.last.prev_token).not_to be_nil
    end

    it 'tracks line and column' do
      lexer = described_class.new("class foo {\n  notify { 'bar': }\n}")
      class_tok = lexer.tokens.find { |t| t.type == :CLASS }
      expect(class_tok.line).to eq(1)
      expect(class_tok.column).to eq(1)
      notify_tok = lexer.tokens.find { |t| t.type == :NAME && t.value == 'notify' }
      expect(notify_tok.line).to eq(2)
    end
  end
end
