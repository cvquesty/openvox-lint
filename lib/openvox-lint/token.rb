# frozen_string_literal: true

module OpenvoxLint
  # Represents a single token produced by the lexer.
  #
  # Each token has a type (Symbol), a raw value (String), and positional
  # metadata (line, column).  Tokens are linked together in a doubly-linked
  # list via +prev_token+ / +next_token+ so that check plugins can easily
  # navigate the stream.
  class Token
    attr_accessor :type, :value, :line, :column,
                  :prev_token, :next_token

    def initialize(type, value, line, column)
      @type   = type
      @value  = value
      @line   = line
      @column = column
    end

    def to_s
      "#{type}(#{value.inspect}) @ #{line}:#{column}"
    end

    def inspect
      "#<OpenvoxLint::Token #{self}>"
    end

    # Convenience: is this token a formatting/whitespace token?
    def formatting?
      FORMATTING_TYPES.include?(type)
    end

    FORMATTING_TYPES = %i[
      WHITESPACE INDENT NEWLINE COMMENT MLCOMMENT SLASH_COMMENT
    ].freeze
  end
end
