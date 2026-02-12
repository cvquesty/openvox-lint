# frozen_string_literal: true

# Resource titles should be quoted.
OpenvoxLint.new_check(:unquoted_resource_title) do
  def check
    title_tokens.each do |tok|
      next unless tok.type == :NAME
      notify :warning,
        message: "unquoted resource title '#{tok.value}'",
        line: tok.line, column: tok.column
    end
  end
end
