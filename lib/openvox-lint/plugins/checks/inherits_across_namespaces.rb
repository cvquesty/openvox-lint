# frozen_string_literal: true

# Classes should not inherit across module namespaces.
OpenvoxLint.new_check(:inherits_across_namespaces) do
  def check
    sem = semantic_tokens
    sem.each_with_index do |tok, i|
      next unless tok.type == :INHERITS
      # The class being inherited is the next name token
      j = i + 1
      next if j >= sem.length
      parent = sem[j]
      next unless parent.type == :NAME || parent.type == :CLASSREF
      # Find the class name (before inherits)
      k = i - 1
      next if k < 0
      child = sem[k]
      next unless child.type == :NAME || child.type == :CLASSREF
      child_ns  = child.value.split('::').first
      parent_ns = parent.value.sub(/\A::/, '').split('::').first
      next if child_ns == parent_ns
      notify :warning,
        message: "class '#{child.value}' inherits from '#{parent.value}' across namespaces",
        line: tok.line, column: tok.column
    end
  end
end
