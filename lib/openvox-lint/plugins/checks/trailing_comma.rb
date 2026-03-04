# frozen_string_literal: true

# Resource bodies and parameter lists should end with a trailing comma.
#
# Only fires inside resource bodies (NAME { ... }) — not inside
# conditionals (if/unless/case), class bodies, or other brace contexts
# where a trailing comma is not expected.
OpenvoxLint.new_check(:trailing_comma) do
  def check
    resource_indexes.each do |res|
      params = res[:param_tokens]
      next if params.empty?

      # Find the last non-formatting token in the resource body
      last = params.reverse_each.find { |t| !t.formatting? }
      next unless last

      # Already has a trailing comma — nothing to do
      next if last.type == :COMMA

      # Only flag after value-like tokens (not structural tokens)
      next unless %i[SSTRING STRING NAME VARIABLE NUMBER TRUE FALSE
                     CLASSREF RBRACK DQSTRING].include?(last.type)

      notify :warning,
        message: 'missing trailing comma after last attribute',
        line: last.line, column: last.column
    end
  end
end
