# frozen_string_literal: true

# The 'ensure' attribute should be the first parameter in a resource body.
OpenvoxLint.new_check(:ensure_first_param) do
  def check
    resource_indexes.each do |resource|
      params = resource[:param_tokens]
      ensure_idx = nil
      first_param_idx = nil
      params.each_with_index do |tok, i|
        if tok.type == :NAME || tok.type == :CLASSREF
          first_param_idx ||= i
          if tok.value == 'ensure'
            ensure_idx = i
            break
          end
        end
      end
      next unless ensure_idx
      next if ensure_idx == first_param_idx
      next unless first_param_idx
      notify :warning,
        message: "ensure is not the first attribute (found at position after first param)",
        line: params[ensure_idx].line,
        column: params[ensure_idx].column
    end
  end
end
