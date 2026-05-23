# frozen_string_literal: true

# Booleans should not be quoted strings.
# e.g. 'true' or "false" should be bare true/false.
OpenvoxLint.new_check(:quoted_booleans) do
  def check
    tokens.each do |tok|
      next unless tok.type == :SSTRING || tok.type == :STRING
      val = tok.value.gsub(/['"]/, '')
      next unless val == 'true' || val == 'false'
      notify :warning,
        message: "quoted boolean '#{val}' — use bare #{val} instead",
        line: tok.line, column: tok.column
    end
  end

  # --fix support: unquote the boolean at the reported column (or fallback
  # gsub). Assumes the problem points to the start of the quoted value.
  def fix(problem)
    idx = problem[:line] - 1
    line = @manifest_lines[idx].dup
    col = (problem[:column] || 1) - 1
    if line[col] == "'" || line[col] == '"'
      quote = line[col]
      # Find matching closing quote for this simple boolean token
      end_col = line.index(quote, col + 1)
      if end_col && %w[true false].include?(line[(col + 1)...end_col])
        val = line[(col + 1)...end_col]
        line[col..end_col] = val
        @manifest_lines[idx] = line
        return
      end
    end
    # Fallback (safe for most manifests)
    @manifest_lines[idx] = line.gsub(/(['"])(true|false)\1/, '\2')
  end
end
