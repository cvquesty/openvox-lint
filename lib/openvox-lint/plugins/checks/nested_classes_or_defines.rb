# frozen_string_literal: true

# Classes and defined types should not be nested inside other classes or defined types.
OpenvoxLint.new_check(:nested_classes_or_defines) do
  def check
    depth = 0
    in_class_or_define = false
    tokens.each do |tok|
      if tok.type == :CLASS || tok.type == :DEFINE
        if in_class_or_define && depth > 0
          kind = tok.type == :CLASS ? 'class' : 'defined type'
          notify :warning,
            message: "#{kind} defined inside another class or defined type",
            line: tok.line, column: tok.column
        end
        in_class_or_define = true
      end
      case tok.type
      when :LBRACE then depth += 1
      when :RBRACE
        depth -= 1
        in_class_or_define = false if depth == 0
      end
    end
  end
end
