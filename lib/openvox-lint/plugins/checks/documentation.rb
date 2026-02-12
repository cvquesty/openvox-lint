# frozen_string_literal: true

# Classes and defined types should be preceded by documentation comments.
OpenvoxLint.new_check(:documentation) do
  def check
    tokens.each_with_index do |tok, i|
      next unless tok.type == :CLASS || tok.type == :DEFINE
      # Look backwards for a comment on the preceding line(s)
      has_doc = false
      j = i - 1
      while j >= 0
        prev = tokens[j]
        if prev.type == :COMMENT && prev.line >= tok.line - 2
          has_doc = true; break
        end
        break unless prev.formatting?
        j -= 1
      end
      next if has_doc
      kind = tok.type == :CLASS ? 'class' : 'defined type'
      notify :warning,
        message: "#{kind} not documented (add a comment above the declaration)",
        line: tok.line, column: tok.column
    end
  end
end
