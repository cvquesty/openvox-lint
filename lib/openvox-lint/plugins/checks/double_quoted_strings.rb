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
end
