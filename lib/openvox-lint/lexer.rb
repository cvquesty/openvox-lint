# frozen_string_literal: true

module OpenvoxLint
  # Tokenises a Puppet / OpenVox manifest string into an Array of Token
  # objects.  The lexer recognises all Puppet 8 / OpenVox 8.x language
  # constructs including heredocs, EPP tags, Deferred/Sensitive types,
  # type aliases, and the full operator set.
  class Lexer
    KEYWORDS = {
      'and' => :AND, 'application' => :APPLICATION, 'attr' => :ATTR,
      'case' => :CASE, 'class' => :CLASS, 'consumes' => :CONSUMES,
      'default' => :DEFAULT, 'define' => :DEFINE, 'else' => :ELSE,
      'elsif' => :ELSIF, 'false' => :FALSE, 'function' => :FUNCTION,
      'if' => :IF, 'import' => :IMPORT, 'in' => :IN,
      'inherits' => :INHERITS, 'node' => :NODE, 'not' => :NOT,
      'or' => :OR, 'private' => :PRIVATE, 'produces' => :PRODUCES,
      'site' => :SITE, 'true' => :TRUE, 'type' => :TYPE,
      'undef' => :UNDEF, 'unless' => :UNLESS,
    }.freeze

    OPERATORS = [
      ['<<|', :LLCOLLECT], ['|>>', :RRCOLLECT],
      ['<=', :LESSEQUAL], ['>=', :GREATEREQUAL],
      ['==', :ISEQUAL], ['!=', :NOTEQUAL],
      ['=~', :MATCH], ['!~', :NOMATCH],
      ['=>', :FARROW], ['+=', :APPENDS],
      ['+>', :PARROW], ['->', :IN_EDGE],
      ['<-', :OUT_EDGE], ['~>', :IN_EDGE_SUB],
      ['<~', :OUT_EDGE_SUB], ['<<', :LSHIFT],
      ['>>', :RSHIFT], ['<|', :LCOLLECT],
      ['|>', :RCOLLECT],
    ].freeze

    SINGLE_CHAR = {
      '{' => :LBRACE, '}' => :RBRACE, '(' => :LPAREN, ')' => :RPAREN,
      '[' => :LBRACK, ']' => :RBRACK, ';' => :SEMIC, ',' => :COMMA,
      '.' => :DOT, '@' => :AT, '|' => :PIPE, '+' => :PLUS,
      '-' => :MINUS, '*' => :TIMES, '%' => :MODULO, '!' => :NOT,
      '?' => :QMARK, '\\' => :BACKSLASH, ':' => :COLON,
      '=' => :EQUALS, '>' => :GREATERTHAN, '<' => :LESSTHAN,
    }.freeze

    REGEX_PREV = %i[
      NODE LBRACE LBRACK LPAREN COMMA EQUALS ISEQUAL NOTEQUAL
      MATCH NOMATCH AND OR NOT IF ELSIF CASE RETURN IN
    ].freeze

    attr_reader :tokens, :manifest_lines

    def initialize(code)
      @code = code
      @manifest_lines = code.lines.map(&:chomp)
      @tokens = []
      @line   = 1
      @column = 1
      @pos    = 0
      tokenise
      link_tokens
    end

    private

    def tokenise # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
      until @pos >= @code.length
        case @code[@pos]
        when "\n"
          emit(:NEWLINE, "\n"); @line += 1; @column = 1
        when "\r"
          if @code[@pos + 1] == "\n"
            emit(:NEWLINE, "\r\n", 2); @line += 1; @column = 1
          else
            emit(:NEWLINE, "\r"); @line += 1; @column = 1
          end
        when ' ', "\t" then scan_whitespace
        when '#'       then scan_comment
        when '/'       then scan_slash
        when "'"       then scan_single_quoted_string
        when '"'       then scan_double_quoted_string
        when '$'       then scan_variable
        when '@'
          if @code[@pos + 1] == '(' || @code[@pos + 1] == '"'
            scan_heredoc
          else
            emit(:AT, '@')
          end
        else
          scan_other
        end
      end
    end

    def scan_whitespace
      start = @pos; start_col = @column
      @pos += 1; @column += 1
      while @pos < @code.length && (@code[@pos] == ' ' || @code[@pos] == "\t")
        @pos += 1; @column += 1
      end
      tok = prev_non_ws_type == :NEWLINE || @tokens.empty? ? :INDENT : :WHITESPACE
      add_token(tok, @code[start...@pos], @line, start_col)
    end

    def scan_comment
      start = @pos; start_col = @column
      @pos += 1; @column += 1
      while @pos < @code.length && @code[@pos] != "\n"
        @pos += 1; @column += 1
      end
      add_token(:COMMENT, @code[start...@pos], @line, start_col)
    end

    def scan_slash
      if @code[@pos + 1] == '*'    then scan_ml_comment
      elsif @code[@pos + 1] == '/' then scan_slash_comment
      elsif regex_possible?        then scan_regex
      else emit(:DIV, '/')
      end
    end

    def scan_ml_comment
      start = @pos; start_line = @line; start_col = @column
      @pos += 2; @column += 2
      until @pos >= @code.length
        if @code[@pos] == '*' && @code[@pos + 1] == '/'
          @pos += 2; @column += 2; break
        end
        if @code[@pos] == "\n" then @line += 1; @column = 1
        else @column += 1; end
        @pos += 1
      end
      add_token(:MLCOMMENT, @code[start...@pos], start_line, start_col)
    end

    def scan_slash_comment
      start = @pos; start_col = @column
      @pos += 2; @column += 2
      while @pos < @code.length && @code[@pos] != "\n"
        @pos += 1; @column += 1
      end
      add_token(:SLASH_COMMENT, @code[start...@pos], @line, start_col)
    end

    def scan_regex
      start = @pos; start_col = @column
      @pos += 1; @column += 1
      while @pos < @code.length && @code[@pos] != '/'
        if @code[@pos] == '\\'
          @pos += 2; @column += 2
        else
          @pos += 1; @column += 1
        end
      end
      @pos += 1; @column += 1
      add_token(:REGEX, @code[start...@pos], @line, start_col)
    end

    def scan_single_quoted_string
      start = @pos; start_col = @column
      @pos += 1; @column += 1
      while @pos < @code.length
        if @code[@pos] == '\\'
          @pos += 2; @column += 2
        elsif @code[@pos] == "'"
          @pos += 1; @column += 1; break
        elsif @code[@pos] == "\n"
          @line += 1; @column = 1; @pos += 1
        else
          @pos += 1; @column += 1
        end
      end
      add_token(:SSTRING, @code[start...@pos], @line, start_col)
    end

    def scan_double_quoted_string
      start = @pos; start_col = @column
      @pos += 1; @column += 1
      has_interp = false
      while @pos < @code.length
        if @code[@pos] == '\\'
          @pos += 2; @column += 2
        elsif @code[@pos] == '$' && @code[@pos + 1] =~ /[a-zA-Z_{:]/
          has_interp = true
          @pos += 1; @column += 1
          while @pos < @code.length && @code[@pos] =~ /[a-zA-Z0-9_:{}]/
            @pos += 1; @column += 1
          end
        elsif @code[@pos] == '"'
          @pos += 1; @column += 1; break
        elsif @code[@pos] == "\n"
          @line += 1; @column = 1; @pos += 1
        else
          @pos += 1; @column += 1
        end
      end
      type = has_interp ? :DQSTRING : :STRING
      add_token(type, @code[start...@pos], @line, start_col)
    end

    def scan_variable
      start = @pos; start_col = @column
      @pos += 1; @column += 1
      while @pos < @code.length && @code[@pos] =~ /[a-zA-Z0-9_:]/
        @pos += 1; @column += 1
      end
      add_token(:VARIABLE, @code[start...@pos], @line, start_col)
    end

    def scan_heredoc
      start_col = @column
      tag_match = @code[@pos..].match(/\A@\(("?)(\w+)\1\s*([\/\-|:tsnLru]*)\)/)
      unless tag_match
        emit(:AT, '@'); return
      end
      tag = tag_match[2]; tag_len = tag_match[0].length
      add_token(:HEREDOC_OPEN, @code[@pos, tag_len], @line, start_col)
      @pos += tag_len; @column += tag_len
      # Skip rest of current line
      while @pos < @code.length && @code[@pos] != "\n"
        @pos += 1; @column += 1
      end
      @pos += 1; @line += 1; @column = 1
      # Read heredoc body
      heredoc_content = +''
      until @pos >= @code.length
        line_start = @pos
        while @pos < @code.length && @code[@pos] != "\n"
          @pos += 1; @column += 1
        end
        current_line = @code[line_start...@pos]
        if current_line.strip =~ /\A[-|]?\s*#{Regexp.escape(tag)}\s*\z/
          @pos += 1 if @pos < @code.length; @line += 1; @column = 1; break
        end
        heredoc_content << current_line << "\n"
        @pos += 1; @line += 1; @column = 1
      end
      add_token(:HEREDOC, heredoc_content, @line, start_col)
    end

    def scan_other # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
      OPERATORS.each do |op, type|
        if @code[@pos, op.length] == op
          emit(type, op, op.length); return
        end
      end
      ch = @code[@pos]
      if SINGLE_CHAR.key?(ch)
        emit(SINGLE_CHAR[ch], ch); return
      end
      if ch =~ /[0-9]/
        scan_number; return
      end
      if ch =~ /[a-zA-Z_]/ || (ch == ':' && @code[@pos + 1] == ':')
        scan_name; return
      end
      emit(:OTHER, ch)
    end

    def scan_number
      start = @pos; start_col = @column
      if @code[@pos] == '0' && @code[@pos + 1] =~ /[xX]/
        @pos += 2; @column += 2
        while @pos < @code.length && @code[@pos] =~ /[0-9a-fA-F_]/
          @pos += 1; @column += 1
        end
      elsif @code[@pos] == '0' && @code[@pos + 1] =~ /[0-7]/
        @pos += 1; @column += 1
        while @pos < @code.length && @code[@pos] =~ /[0-7_]/
          @pos += 1; @column += 1
        end
      else
        while @pos < @code.length && @code[@pos] =~ /[0-9_]/
          @pos += 1; @column += 1
        end
        if @pos < @code.length && @code[@pos] == '.' && @code[@pos + 1] =~ /[0-9]/
          @pos += 1; @column += 1
          while @pos < @code.length && @code[@pos] =~ /[0-9_]/
            @pos += 1; @column += 1
          end
        end
        if @pos < @code.length && @code[@pos] =~ /[eE]/
          @pos += 1; @column += 1
          if @pos < @code.length && @code[@pos] =~ /[+\-]/
            @pos += 1; @column += 1
          end
          while @pos < @code.length && @code[@pos] =~ /[0-9]/
            @pos += 1; @column += 1
          end
        end
      end
      add_token(:NUMBER, @code[start...@pos], @line, start_col)
    end

    def scan_name
      start = @pos; start_col = @column
      if @code[@pos] == ':' && @code[@pos + 1] == ':'
        @pos += 2; @column += 2
      end
      while @pos < @code.length && @code[@pos] =~ /[a-zA-Z0-9_]/
        @pos += 1; @column += 1
        if @pos + 1 < @code.length && @code[@pos] == ':' && @code[@pos + 1] == ':'
          @pos += 2; @column += 2
        end
      end
      word = @code[start...@pos]
      if KEYWORDS.key?(word)
        add_token(KEYWORDS[word], word, @line, start_col)
      elsif word =~ /\A[A-Z]/
        add_token(:CLASSREF, word, @line, start_col)
      else
        add_token(:NAME, word, @line, start_col)
      end
    end

    def emit(type, value, length = nil)
      length ||= value.length
      add_token(type, value, @line, @column)
      @pos += length; @column += length
    end

    def add_token(type, value, line, column)
      @tokens << Token.new(type, value, line, column)
    end

    def link_tokens
      @tokens.each_with_index do |tok, i|
        tok.prev_token = i > 0 ? @tokens[i - 1] : nil
        tok.next_token = @tokens[i + 1]
      end
    end

    def prev_non_ws_type
      @tokens.reverse_each do |t|
        return t.type unless t.type == :WHITESPACE || t.type == :INDENT
      end
      nil
    end

    def regex_possible?
      return true if @tokens.empty?
      REGEX_PREV.include?(prev_non_ws_type)
    end
  end
end
