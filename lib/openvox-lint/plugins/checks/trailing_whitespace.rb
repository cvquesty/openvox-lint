# frozen_string_literal: true

# Detects trailing whitespace at the end of lines.
OpenvoxLint.new_check(:trailing_whitespace) do
  def check
    manifest_lines.each_with_index do |line, idx|
      next unless line =~ /\s+$/
      notify :warning,
        message: 'trailing whitespace found',
        line: idx + 1,
        column: line.rstrip.length + 1
    end
  end

  # --fix support: strip trailing whitespace from the offending line.
  def fix(problem)
    idx = problem[:line] - 1
    @manifest_lines[idx] = @manifest_lines[idx].rstrip
  end
end
