# frozen_string_literal: true

# Resource reference titles must start with a capital letter.
# e.g. File['/tmp/foo'] not file['/tmp/foo']
OpenvoxLint.new_check(:resource_reference_without_title_capital) do
  def check
    sem = semantic_tokens
    sem.each_with_index do |tok, i|
      next unless tok.type == :NAME
      next if i + 1 >= sem.length
      next unless sem[i + 1].type == :LBRACK
      # This is name[...] which should be Name[...] for a resource reference
      next if tok.value =~ /\A[A-Z]/
      # Skip function calls and normal array access
      next if %w[split join include contain require].include?(tok.value)
      notify :warning,
        message: "resource reference '#{tok.value}' must start with a capital letter",
        line: tok.line, column: tok.column
    end
  end
end
