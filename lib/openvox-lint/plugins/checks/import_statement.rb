# frozen_string_literal: true

# The 'import' statement was removed in Puppet 4+.
OpenvoxLint.new_check(:import_statement) do
  def check
    tokens.each do |tok|
      next unless tok.type == :IMPORT
      notify :error,
        message: "'import' statement was removed in Puppet 4; use module autoloading instead",
        line: tok.line, column: tok.column
    end
  end
end
