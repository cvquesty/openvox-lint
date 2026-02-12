# frozen_string_literal: true

# Variables in double-quoted strings should be enclosed in braces.
# e.g. "$foo" should be "${foo}"
OpenvoxLint.new_check(:variables_not_enclosed) do
  def check
    tokens.each do |tok|
      next unless tok.type == :DQSTRING || tok.type == :STRING
      val = tok.value
      # Look for $var not followed by { inside double-quoted strings
      next unless val =~ /\$([a-zA-Z_][a-zA-Z0-9_:]*)/
      next if val =~ /\$\{/  # already enclosed
      notify :warning,
        message: 'variable not enclosed in braces within string',
        line: tok.line,
        column: tok.column
    end
  end
end
