# frozen_string_literal: true

# Detects deprecated Hiera 3 functions that are removed in Puppet 8 / OpenVox 8.
#
# Hiera 3 is fully deprecated.  Only Hiera 5 is supported in Puppet 8+.
# The legacy hiera() functions were compatibility shims that have been removed.
#
# Deprecated functions:
#   - hiera()         -> lookup()
#   - hiera_array()   -> lookup(..., Array, 'unique')
#   - hiera_hash()    -> lookup(..., Hash, 'hash')
#   - hiera_include() -> lookup(...).include
#
# Use the Hiera 5 lookup() function instead.
OpenvoxLint.new_check(:hiera3_function) do
  HIERA3_FUNCS = %w[hiera hiera_array hiera_hash hiera_include].freeze

  def check
    tokens.each do |tok|
      next unless tok.type == :NAME && HIERA3_FUNCS.include?(tok.value)
      notify :error,
        message: "deprecated Hiera 3 function '#{tok.value}()' — use Hiera 5 lookup() instead",
        line: tok.line, column: tok.column
    end
  end
end
