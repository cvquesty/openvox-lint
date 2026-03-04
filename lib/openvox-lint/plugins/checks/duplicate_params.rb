# frozen_string_literal: true

# No duplicate parameters in resource declarations.
OpenvoxLint.new_check(:duplicate_params) do
  def check
    resource_indexes.each do |res|
      seen = {}
      params = res[:param_tokens]
      params.each_with_index do |tok, i|
        next unless tok.type == :NAME
        # param_tokens are already semantic (non-formatting), so the
        # next token is directly adjacent.
        j = i + 1
        next unless j < params.length && params[j].type == :FARROW
        if seen[tok.value]
          notify :error,
            message: "duplicate parameter '#{tok.value}'",
            line: tok.line, column: tok.column
        end
        seen[tok.value] = true
      end
    end
  end
end
