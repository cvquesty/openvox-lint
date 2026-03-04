# frozen_string_literal: true

# Variables in double-quoted strings should be enclosed in braces.
# e.g. "$foo" should be "${foo}"
#
# Correctly handles strings with a mix of enclosed and unenclosed
# variables — e.g. "$foo and ${bar}" flags the unenclosed $foo even
# though ${bar} is properly enclosed.
OpenvoxLint.new_check(:variables_not_enclosed) do
  def check
    tokens.each do |tok|
      next unless tok.type == :DQSTRING || tok.type == :STRING
      val = tok.value
      # Scan for any $var that is NOT preceded by ${ (already enclosed).
      # We use a negative lookbehind to skip ${...} patterns and only
      # match bare $varname references.
      val.scan(/(?<!\$)\$(?!\{)([a-zA-Z_][a-zA-Z0-9_:]*)/) do
        notify :warning,
          message: 'variable not enclosed in braces within string',
          line: tok.line,
          column: tok.column
      end
    end
  end
end
