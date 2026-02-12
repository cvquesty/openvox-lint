# frozen_string_literal: true

# A string containing only a variable should not be quoted.
# e.g. "${foo}" should be $foo
OpenvoxLint.new_check(:only_variable_string) do
  def check
    tokens.each do |tok|
      next unless tok.type == :DQSTRING
      val = tok.value
      # Match strings like "${varname}" or "$varname" with nothing else
      next unless val =~ /\A"\$\{?[a-zA-Z_][a-zA-Z0-9_:]*\}?"\z/
      notify :warning,
        message: 'string containing only a variable is unnecessarily quoted',
        line: tok.line,
        column: tok.column
    end
  end
end
