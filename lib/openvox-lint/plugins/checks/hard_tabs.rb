# frozen_string_literal: true

# Detects hard tab characters. Two-space soft tabs are required.
OpenvoxLint.new_check(:hard_tabs) do
  def check
    manifest_lines.each_with_index do |line, idx|
      col = line.index("\t")
      next unless col
      notify :warning,
        message: 'tab character found (use 2-space soft tabs)',
        line: idx + 1,
        column: col + 1
    end
  end
end
