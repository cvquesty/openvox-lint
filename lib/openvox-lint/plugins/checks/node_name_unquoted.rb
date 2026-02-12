# frozen_string_literal: true

# Node names should be quoted strings, not bare words.
OpenvoxLint.new_check(:node_name_unquoted) do
  def check
    sem = semantic_tokens
    sem.each_with_index do |tok, i|
      next unless tok.type == :NODE
      j = i + 1
      next if j >= sem.length
      name = sem[j]
      next unless name.type == :NAME
      notify :warning,
        message: "unquoted node name '#{name.value}' — use a quoted string",
        line: name.line, column: name.column
    end
  end
end
