# frozen_string_literal: true

# Selectors (?) should not be used inside resource declarations.
OpenvoxLint.new_check(:selector_inside_resource) do
  def check
    resource_indexes.each do |res|
      res[:param_tokens].each do |tok|
        next unless tok.type == :QMARK
        notify :warning,
          message: 'selector (?) inside resource body; use a variable or conditional instead',
          line: tok.line, column: tok.column
      end
    end
  end
end
