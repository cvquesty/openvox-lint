# frozen_string_literal: true

# Lines should not exceed 140 characters.
OpenvoxLint.new_check(:line_length) do
  MAX_LENGTH = 140

  def check
    manifest_lines.each_with_index do |line, idx|
      next if line.length <= MAX_LENGTH
      # Exception: long puppet:/// source URLs
      next if line =~ /puppet:\/\//
      notify :warning,
        message: "line has #{line.length} characters (max #{MAX_LENGTH})",
        line: idx + 1,
        column: MAX_LENGTH + 1
    end
  end
end
