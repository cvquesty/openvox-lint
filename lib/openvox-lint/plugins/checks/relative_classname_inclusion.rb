# frozen_string_literal: true

# Use absolute class names in include/require/contain statements.
OpenvoxLint.new_check(:relative_classname_inclusion) do
  INCLUDE_FUNCS = %w[include require contain].freeze

  def check
    sem = semantic_tokens
    sem.each_with_index do |tok, i|
      next unless tok.type == :NAME && INCLUDE_FUNCS.include?(tok.value)
      j = i + 1
      next if j >= sem.length
      name_tok = sem[j]
      next unless name_tok.type == :NAME || name_tok.type == :SSTRING || name_tok.type == :STRING
      class_name = name_tok.value.gsub(/['"]/, '')
      next if class_name.start_with?('::') || class_name.empty?
      # Single-segment names are OK (they're unambiguous)
      next unless class_name.include?('::')
      notify :warning,
        message: "class name '#{class_name}' should be fully qualified (start with ::)",
        line: name_tok.line, column: name_tok.column
    end
  end
end
