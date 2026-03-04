# frozen_string_literal: true

# Resource reference titles must start with a capital letter.
# e.g. File['/tmp/foo'] not file['/tmp/foo']
OpenvoxLint.new_check(:resource_reference_without_title_capital) do
  # Puppet built-in functions and common stdlib functions that accept
  # bracket/index syntax (name[...]).  These are NOT resource
  # references and must not be flagged.
  FUNCTION_ALLOWLIST = %w[
    split join include contain require
    each map filter reduce select reject
    slice flatten any all empty
    assert_type create_resources defined dig
    ensure_packages ensure_resource epp fail
    fqdn_rand generate hiera hiera_array hiera_hash hiera_include
    inline_epp inline_template lookup match md5 notice
    realize regsubst sha1 sprintf tag template unique versioncmp
    with
  ].freeze

  def check
    sem = semantic_tokens
    sem.each_with_index do |tok, i|
      next unless tok.type == :NAME
      next if i + 1 >= sem.length
      next unless sem[i + 1].type == :LBRACK
      # This is name[...] which should be Name[...] for a resource reference
      next if tok.value =~ /\A[A-Z]/
      # Skip function calls, method calls, and normal array access
      next if FUNCTION_ALLOWLIST.include?(tok.value)
      notify :warning,
        message: "resource reference '#{tok.value}' must start with a capital letter",
        line: tok.line, column: tok.column
    end
  end
end
