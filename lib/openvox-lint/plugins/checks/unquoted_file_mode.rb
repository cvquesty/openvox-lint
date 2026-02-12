# frozen_string_literal: true

# File modes should be quoted strings.
OpenvoxLint.new_check(:unquoted_file_mode) do
  def check
    tokens.each_with_index do |tok, i|
      next unless tok.type == :NAME && tok.value == 'mode'
      arrow = next_non_ws(i + 1)
      next unless arrow && arrow.type == :FARROW
      val = next_non_ws(tokens.index(arrow) + 1)
      next unless val && val.type == :NUMBER
      notify :warning,
        message: 'unquoted file mode',
        line: val.line, column: val.column
    end
  end

  private

  def next_non_ws(start)
    (start...tokens.length).each { |j| return tokens[j] unless tokens[j].formatting? }
    nil
  end
end
