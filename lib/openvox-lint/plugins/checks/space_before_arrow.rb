# frozen_string_literal: true

# There should be at most one space before a hash rocket (=>)
# when there is only one parameter.
OpenvoxLint.new_check(:space_before_arrow) do
  def check
    tokens.each_with_index do |tok, i|
      next unless tok.type == :FARROW
      next if i == 0
      prev = tokens[i - 1]
      next unless prev.type == :WHITESPACE
      next if prev.value.length <= 1
      # Allow if this is in a multi-param aligned block
      # (arrow_alignment handles that)
      notify :warning,
        message: "more than one space before => (found #{prev.value.length})",
        line: tok.line, column: prev.column
    end
  end
end
