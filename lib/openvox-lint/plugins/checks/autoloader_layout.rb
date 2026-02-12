# frozen_string_literal: true

# Class/define names should match the autoloader file path.
# e.g. class foo::bar::baz should be in foo/manifests/bar/baz.pp
OpenvoxLint.new_check(:autoloader_layout) do
  def check
    sem = semantic_tokens
    sem.each_with_index do |tok, i|
      next unless tok.type == :CLASS || tok.type == :DEFINE
      j = i + 1
      next if j >= sem.length
      name_tok = sem[j]
      next unless name_tok.type == :NAME || name_tok.type == :CLASSREF
      name = name_tok.value
      parts = name.split('::')
      next if parts.empty?
      expected_path = if parts.length == 1
                        "#{parts[0]}/manifests/init.pp"
                      else
                        "#{parts[0]}/manifests/#{parts[1..].join('/')}.pp"
                      end
      next if fullpath.end_with?(expected_path)
      # Also check with just the filename portion
      expected_file = parts.length == 1 ? 'init.pp' : "#{parts.last}.pp"
      next if filename == expected_file
      notify :warning,
        message: "#{tok.value} '#{name}' not in expected autoloader path '#{expected_path}'",
        line: name_tok.line, column: name_tok.column
    end
  end
end
