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

    describe 'heredocs' do
      it 'tokenises HEREDOC_OPEN and HEREDOC' do
        code = <<~PP
          $x = @(END)
          hello
          END
        PP
        lexer = described_class.new(code)
        expect(lexer.tokens.map(&:type)).to include(:HEREDOC_OPEN, :HEREDOC)
        heredoc = lexer.tokens.find { |t| t.type == :HEREDOC }
        expect(heredoc.value).to eq("hello\n")
      end

      it 'allows a trailing comma after the open tag' do
        code = <<~PP
          file { '/tmp/x':
            content => @(END/L),
              hello
              | END
          }
        PP
        lexer = described_class.new(code)
        expect(lexer.tokens.map(&:type)).to include(:HEREDOC_OPEN, :HEREDOC)
        heredoc = lexer.tokens.find { |t| t.type == :HEREDOC }
        expect(heredoc.value).to include('hello')
      end

      it 'tokenises margin-strip and dash-strip end tags' do
        ['| END', '- END'].each do |end_tag|
          code = "$x = @(END)\n  hello\n  #{end_tag}\n"
          lexer = described_class.new(code)
          expect(lexer.tokens.map(&:type)).to include(:HEREDOC_OPEN, :HEREDOC),
            "expected #{end_tag.inspect} to close a heredoc"
        end
      end

      it 'raises on an unterminated heredoc' do
        code = <<~PP
          $x = @(END)
          hello
        PP
        expect { described_class.new(code) }.to raise_error(
          OpenvoxLint::Error,
          /unterminated heredoc starting at line 1/
        )
      end

      # Contract: `| END,` is not a valid terminator (junk after the tag).
      # The line is treated as heredoc content, so the scan continues and
      # EOF without a whole-line end tag raises — fail-closed, not a clean lint.
      it 'raises when the end tag has trailing junk' do
        code = <<~PP
          file { '/tmp/whatever.txt':
            content => @(END/L)
              content
              | END,
            mode    => '0644',
          }
        PP
        expect { described_class.new(code) }.to raise_error(
          OpenvoxLint::Error,
          /unterminated heredoc starting at line 2/
        )
      end
    end
  end
end
