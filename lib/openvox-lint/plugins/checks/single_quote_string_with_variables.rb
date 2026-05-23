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

  # --fix support: swap outer single quotes to double (may require manual
  # review for literal $ or inner quotes per style exceptions).
  def fix(problem)
    idx = problem[:line] - 1
    line = @manifest_lines[idx].dup
    col = (problem[:column] || 1) - 1
    if line[col] == "'"
      end_col = line.index("'", col + 1)
      if end_col
        inner = line[(col + 1)...end_col]
        line[col..end_col] = '"' + inner + '"'
        @manifest_lines[idx] = line
      end
    end
  end
end
