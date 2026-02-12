# frozen_string_literal: true

# Hiera 3 functions (hiera, hiera_array, hiera_hash, hiera_include)
# are removed in Puppet 8 / OpenVox 8. Use lookup() instead.
OpenvoxLint.new_check(:hiera3_function) do
  HIERA3_FUNCS = %w[hiera hiera_array hiera_hash hiera_include].freeze

  def check
    tokens.each do |tok|
      next unless tok.type == :NAME && HIERA3_FUNCS.include?(tok.value)
      notify :error,
        message: "'#{tok.value}()' is removed in Puppet 8 / OpenVox 8 — use lookup() instead",
        line: tok.line, column: tok.column
    end
  end
end
