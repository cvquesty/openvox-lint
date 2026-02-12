# frozen_string_literal: true

# Variable names should not contain dashes.
OpenvoxLint.new_check(:variable_contains_dash) do
  def check
    tokens.each do |tok|
      next unless tok.type == :VARIABLE
      next unless tok.value.include?('-')
      notify :warning,
        message: "variable '#{tok.value}' contains a dash",
        line: tok.line,
        column: tok.column
    end
  end
end
