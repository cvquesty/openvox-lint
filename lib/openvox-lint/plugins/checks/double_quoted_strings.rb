# frozen_string_literal: true

# Double-quoted strings that do not contain variables or escape sequences
# should use single quotes instead.
#
# Exception: when the string body contains literal single-quote characters
# (e.g. "it's running", "use 'ensure'"), double quotes are the correct
# choice to avoid backslash-escaping those quotes.  This is standard
# Puppet style and must not be flagged.
OpenvoxLint.new_check(:double_quoted_strings) do
  def check
    tokens.each do |tok|
      next unless tok.type == :STRING
      val = tok.value
      # STRING type means double-quoted without interpolation
      next if val =~ /\\[nt\\$"]/  # has meaningful escapes
      next if val.length <= 2      # empty string ""
      # Strip surrounding double quotes to inspect inner content.
      inner = val[1..-2] || ''
      next if inner.include?("'")  # contains nested single quotes
      notify :warning,
        message: 'string does not contain variables or escapes; use single quotes',
        line: tok.line,
        column: tok.column
    end
  end

  # --fix support: convert the double-quoted string (no interp) to single
  # quotes by swapping the outer delimiters at the reported column.
  def fix(problem)
    idx = problem[:line] - 1
    line = @manifest_lines[idx].dup
    col = (problem[:column] || 1) - 1
    if line[col] == '"'
      end_col = line.index('"', col + 1)
      if end_col
        inner = line[(col + 1)...end_col]
        line[col..end_col] = "'" + inner + "'"
        @manifest_lines[idx] = line
      end
    end
  end
end
