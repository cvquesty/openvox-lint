# frozen_string_literal: true

# puppet:// URLs should include the modules mount point.
# e.g. puppet:///modules/mymod/file not puppet:///mymod/file
OpenvoxLint.new_check(:puppet_url_without_modules) do
  def check
    tokens.each do |tok|
      next unless tok.type == :SSTRING || tok.type == :STRING || tok.type == :DQSTRING
      val = tok.value.gsub(/['"]/, '')
      next unless val.start_with?('puppet:///')
      next if val.start_with?('puppet:///modules/')
      notify :warning,
        message: "puppet:// URL should include /modules/ mount point",
        line: tok.line, column: tok.column
    end
  end
end
