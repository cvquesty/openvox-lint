# frozen_string_literal: true

# Double-quoted strings that do not contain variables or escape sequences
# should use single quotes instead.
OpenvoxLint.new_check(:double_quoted_strings) do
  def check
    tokens.each do |tok|
      next unless tok.type == :STRING
      val = tok.value
      # STRING type means double-quoted without interpolation
      next if val =~ /\\[nt\\$"]/  # has meaningful escapes
      next if val.length <= 2      # empty string ""
      notify :warning,
        message: 'string does not contain variables or escapes; use single quotes',
        line: tok.line,
        column: tok.column
    end
  end
end
