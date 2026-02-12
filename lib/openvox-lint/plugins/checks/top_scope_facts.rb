# frozen_string_literal: true

# Top-scope fact variables ($::fact_name) are deprecated in Puppet 8 / OpenVox 8.
# Use $facts['fact_name'] instead.
OpenvoxLint.new_check(:top_scope_facts) do
  def check
    tokens.each do |tok|
      next unless tok.type == :VARIABLE
      name = tok.value.sub(/^\$/, '')
      next unless name.start_with?('::')
      fact_name = name.sub(/\A::/, '')
      # Skip module-qualified variables (e.g. ::mymodule::param)
      next if fact_name.include?('::')
      notify :warning,
        message: "top-scope fact '$::#{fact_name}' — use $facts['#{fact_name}'] instead (Puppet 8 / OpenVox 8)",
        line: tok.line, column: tok.column
    end
  end
end
