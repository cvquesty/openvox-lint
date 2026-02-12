# frozen_string_literal: true

# Case statements should have a default case.
OpenvoxLint.new_check(:case_without_default) do
  def check
    sem = semantic_tokens
    sem.each_with_index do |tok, i|
      next unless tok.type == :CASE
      # Find the matching brace block
      j = i + 1
      j += 1 while j < sem.length && sem[j].type != :LBRACE
      next if j >= sem.length
      depth = 1; k = j + 1; has_default = false
      while k < sem.length && depth > 0
        case sem[k].type
        when :LBRACE  then depth += 1
        when :RBRACE  then depth -= 1
        when :DEFAULT then has_default = true if depth == 1
        end
        k += 1
      end
      next if has_default
      notify :warning,
        message: 'case statement without a default case',
        line: tok.line, column: tok.column
    end
  end
end
