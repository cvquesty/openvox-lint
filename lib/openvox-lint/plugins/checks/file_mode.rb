# frozen_string_literal: true

# File mode should be a 4-digit quoted string or symbolic mode.
OpenvoxLint.new_check(:file_mode) do
  def check
    tokens.each_with_index do |tok, i|
      next unless tok.type == :NAME && tok.value == 'mode'
      arrow = next_non_ws(i + 1)
      next unless arrow && arrow.type == :FARROW
      val = next_non_ws(tokens.index(arrow) + 1)
      next unless val
      if val.type == :NUMBER
        notify :warning,
          message: "file mode should be a quoted string, not a bare number",
          line: val.line, column: val.column
      elsif val.type == :SSTRING || val.type == :STRING
        mode = val.value.gsub(/['"]/, '')
        next if mode =~ /\A[0-7]{4}\z/       # 4-digit octal
        next if mode =~ /\A[ugoa]+[=+-]/      # symbolic
        notify :warning,
          message: "file mode '#{mode}' is not a valid 4-digit octal or symbolic mode",
          line: val.line, column: val.column
      end
    end
  end

  private

  def next_non_ws(start)
    (start...tokens.length).each { |j| return tokens[j] unless tokens[j].formatting? }
    nil
  end
end
