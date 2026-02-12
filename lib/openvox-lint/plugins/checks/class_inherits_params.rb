# frozen_string_literal: true

# Class inheritance is discouraged. Prefer composition (include/contain/require).
OpenvoxLint.new_check(:class_inherits_params) do
  def check
    tokens.each do |tok|
      next unless tok.type == :INHERITS
      notify :warning,
        message: 'class inheritance is discouraged; use composition (include, contain, require) instead',
        line: tok.line, column: tok.column
    end
  end
end
