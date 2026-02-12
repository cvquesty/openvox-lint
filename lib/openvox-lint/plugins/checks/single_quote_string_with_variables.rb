# frozen_string_literal: true

# Single-quoted strings containing variable-like patterns ($var)
# should use double quotes for interpolation.
OpenvoxLint.new_check(:single_quote_string_with_variables) do
  def check
    tokens.each do |tok|
      next unless tok.type == :SSTRING
      val = tok.value
      next unless val =~ /\$[a-zA-Z_]/
      notify :warning,
        message: 'single-quoted string contains a variable reference; use double quotes for interpolation',
        line: tok.line, column: tok.column
    end
  end
end
