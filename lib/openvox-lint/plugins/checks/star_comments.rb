# frozen_string_literal: true

# Use # comments, not /* */ multi-line comments.
OpenvoxLint.new_check(:star_comments) do
  def check
    tokens.each do |tok|
      next unless tok.type == :MLCOMMENT
      notify :warning,
        message: 'use # (hash) comments instead of /* */ block comments',
        line: tok.line, column: tok.column
    end
  end
end
