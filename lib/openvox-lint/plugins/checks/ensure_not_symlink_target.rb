# frozen_string_literal: true

# Symlinks should use ensure => link with a target attribute,
# not ensure => '/path/to/target'.
OpenvoxLint.new_check(:ensure_not_symlink_target) do
  def check
    tokens.each_with_index do |tok, i|
      next unless tok.type == :NAME && tok.value == 'ensure'
      arrow = find_next_non_ws(i + 1)
      next unless arrow && arrow.type == :FARROW
      val = find_next_non_ws(tokens.index(arrow) + 1)
      next unless val
      next unless (val.type == :SSTRING || val.type == :STRING) && val.value =~ /\//
      notify :warning,
        message: 'ensure should not be set to a symlink target; use ensure => link with a target attribute',
        line: val.line,
        column: val.column
    end
  end

  private

  def find_next_non_ws(start)
    (start...tokens.length).each do |j|
      return tokens[j] unless tokens[j].formatting?
    end
    nil
  end
end
