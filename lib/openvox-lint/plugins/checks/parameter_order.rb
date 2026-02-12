# frozen_string_literal: true

# Parameters with defaults should come after parameters without defaults.
OpenvoxLint.new_check(:parameter_order) do
  def check
    [class_indexes, defined_type_indexes].flatten.each do |defn|
      params = defn[:param_tokens]
      found_default = false
      params.each_with_index do |tok, i|
        next unless tok.type == :VARIABLE
        # Look ahead for = (default value)
        j = i + 1
        j += 1 while j < params.length && params[j].formatting?
        has_default = j < params.length && params[j].type == :EQUALS
        if has_default
          found_default = true
        elsif found_default
          notify :warning,
            message: "parameter '#{tok.value}' without default follows a parameter with a default",
            line: tok.line, column: tok.column
        end
      end
    end
  end
end
