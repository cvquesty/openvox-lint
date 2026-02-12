# frozen_string_literal: true

# Resource bodies and parameter lists should end with a trailing comma.
OpenvoxLint.new_check(:trailing_comma) do
  def check
    tokens.each_with_index do |tok, i|
      next unless tok.type == :RBRACE || tok.type == :RPAREN
      # Find the previous non-whitespace token
      j = i - 1
      j -= 1 while j >= 0 && tokens[j].formatting?
      next if j < 0
      prev = tokens[j]
      # Skip if previous is opening brace/paren (empty block) or already a comma
      next if %i[LBRACE LPAREN COMMA RBRACE].include?(prev.type)
      # Only flag inside parameter lists and resource bodies
      next unless prev.type == :SSTRING || prev.type == :STRING || prev.type == :NAME ||
                  prev.type == :VARIABLE || prev.type == :NUMBER || prev.type == :TRUE ||
                  prev.type == :FALSE || prev.type == :CLASSREF || prev.type == :RBRACK
      notify :warning,
        message: 'missing trailing comma after last attribute',
        line: prev.line, column: prev.column
    end
  end
end
