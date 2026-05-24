# frozen_string_literal: true

module OpenvoxLint
  # Runs all enabled checks against a tokenised manifest.
  class Checks
    attr_reader :problems

    def initialize(tokens:, manifest_lines:, fullpath:, configuration:)
      @tokens         = tokens
      @manifest_lines = manifest_lines
      @fullpath       = fullpath
      @configuration  = configuration
      @problems       = []
      @ignore_comments = parse_ignore_comments
    end

    def run
      OpenvoxLint.checks.each do |name, klass|
        next unless @configuration.check_enabled?(name)
        plugin = klass.new
        results = plugin.run(
          tokens: @tokens, manifest_lines: @manifest_lines,
          fullpath: @fullpath, ignore_comments: @ignore_comments,
        )
        @problems.concat(results)
        plugin.fix_problems if @configuration.fix && plugin.respond_to?(:fix_problems)
      end
      @problems.sort_by { |p| [p[:line] || 0, p[:column] || 0] }
    end

    private

    # Parse inline and block-style lint:ignore comments.
    #
    # Inline:  # lint:ignore:check_name   — suppresses on the same line
    # Block:   # lint:ignore:check_name
    #          ...code...
    #          # lint:endignore            — suppresses from ignore to endignore
    def parse_ignore_comments
      results = []
      open_blocks = []  # stack of { start_line:, checks: }

      @tokens.each do |tok|
        next unless tok.type == :COMMENT

        comment_text = tok.value.to_s

        if comment_text =~ /lint:endignore/i
          # Close the most recent open block
          block = open_blocks.pop
          if block
            block[:end_line] = tok.line
            results << block
          end
        elsif comment_text =~ /lint:ignore/i
          # Robust extraction: find every "lint:ignore:" and take the following name(s)
          # until the next "lint:" directive or end of comment.
          checks = []
          text = comment_text
          while (idx = text.index(/lint:ignore:/i))
            # Take from after this directive until the next directive or end
            remaining = text[idx + 'lint:ignore:'.length .. -1]
            next_dir = remaining.index(/lint:/i) || remaining.length
            chunk = remaining[0...next_dir]
            checks += chunk.split(/[,\s]+/).map { |s| s.strip.tr('-', '_').downcase }.reject(&:empty?)
            # Advance past this directive for the next search
            text = text[idx + 1 .. -1] || ''
          end
          checks.uniq!
          if comment_text =~ /lint:ignore(?!\s*:)/i && checks.empty?
            checks = []
          end

          # If there's code on the same line before this comment, treat
          # it as inline-only (same line).  Otherwise open a block.
          if inline_ignore?(tok)
            results << { start_line: tok.line, end_line: tok.line, checks: checks }
          else
            open_blocks.push({ start_line: tok.line, end_line: nil, checks: checks })
          end
        end
      end

      # Any unclosed blocks extend to end-of-file
      open_blocks.each do |block|
        block[:end_line] = Float::INFINITY
        results << block
      end

      results
    end

    # An ignore comment is "inline" if there is a non-formatting token
    # on the same line before it (i.e. it sits at the end of a code line).
    def inline_ignore?(comment_token)
      @tokens.any? do |t|
        t.line == comment_token.line &&
          t.column < comment_token.column &&
          !t.formatting?
      end
    end
  end
end
