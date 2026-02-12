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

    def parse_ignore_comments
      results = []
      @tokens.each do |tok|
        next unless tok.type == :COMMENT
        if tok.value =~ /lint:ignore:(.+)/
          results << { line: tok.line, checks: Regexp.last_match(1).strip.split(/\s*,\s*/) }
        elsif tok.value =~ /lint:ignore\b/
          results << { line: tok.line, checks: [] }
        end
      end
      results
    end
  end
end
