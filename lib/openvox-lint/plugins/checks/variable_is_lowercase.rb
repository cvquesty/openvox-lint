# frozen_string_literal: true

# All variable names must be lowercase.
OpenvoxLint.new_check(:variable_is_lowercase) do
  def check
    tokens.each do |tok|
      next unless tok.type == :VARIABLE
      name = tok.value.sub(/^\$:*/, '')
      next if name =~ /\A[a-z_][a-z0-9_:]*\z/ || name.empty?
      notify :warning,
        message: "variable '#{tok.value}' contains uppercase characters",
        line: tok.line,
        column: tok.column
    end
  end
end
