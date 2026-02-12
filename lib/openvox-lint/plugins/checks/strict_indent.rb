# frozen_string_literal: true

# Indentation should use exactly 2 spaces per level.
OpenvoxLint.new_check(:strict_indent) do
  def check
    manifest_lines.each_with_index do |line, idx|
      next if line.strip.empty?
      next if line =~ /\A#/  # comment lines
      indent = line.match(/\A( *)/)[1]
      next if indent.length.even?
      notify :warning,
        message: "odd number of spaces in indentation (#{indent.length}); use 2-space increments",
        line: idx + 1, column: 1
    end
  end
end
