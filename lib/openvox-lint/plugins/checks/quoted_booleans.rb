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
end
