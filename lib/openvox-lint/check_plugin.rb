# frozen_string_literal: true

module OpenvoxLint
  # Base class for every lint check.  Subclass via OpenvoxLint.new_check.
  class CheckPlugin
    attr_reader :problems

    class << self
      attr_reader :check_name
    end

    def initialize
      @problems = []
    end

    def run(tokens:, manifest_lines:, fullpath:, ignore_comments: [])
      @tokens         = tokens
      @manifest_lines = manifest_lines
      @fullpath       = fullpath
      @path           = fullpath
      @filename       = File.basename(fullpath)
      @problems       = []
      @ignore_comments = ignore_comments
      check
      @problems.reject! { |p| ignored?(p) }
      @problems
    end

    def fix_problems
      @problems.each do |problem|
        fix(problem)
      rescue OpenvoxLint::NoFix
        next
      end
    end

    protected

    def check
      raise NotImplementedError, "#{self.class} must implement #check"
    end

    def fix(_problem)
      raise OpenvoxLint::NoFix
    end

    attr_reader :tokens, :manifest_lines, :fullpath, :path, :filename

    def notify(kind, details)
      details[:kind]  = kind
      details[:check] = self.class.check_name
      details[:path]  = @path
      @problems << details
    end

    def semantic_tokens
      tokens.reject(&:formatting?)
    end

    def resource_indexes
      @resource_indexes ||= compute_resource_indexes
    end

    def class_indexes
      @class_indexes ||= find_keyword_indexes(:CLASS)
    end

    def defined_type_indexes
      @defined_type_indexes ||= find_keyword_indexes(:DEFINE)
    end

    def node_indexes
      @node_indexes ||= find_keyword_indexes(:NODE)
    end

    def title_tokens
      @title_tokens ||= compute_title_tokens
    end

    private

    def ignored?(problem)
      return false if @ignore_comments.empty?
      line = problem[:line]
      @ignore_comments.any? do |ic|
        ic[:line] == line && (ic[:checks].empty? || ic[:checks].include?(problem[:check].to_s))
      end
    end

    def compute_resource_indexes
      results = []; i = 0; sem = semantic_tokens
      while i < sem.length
        if sem[i].type == :NAME && i + 1 < sem.length && sem[i + 1].type == :LBRACE
          rtype = sem[i]; brace = i + 1; depth = 1; j = brace + 1; params = []
          while j < sem.length && depth > 0
            case sem[j].type
            when :LBRACE then depth += 1
            when :RBRACE then depth -= 1
            end
            # Only collect tokens at depth 1 — the resource's own
            # parameters.  Tokens at depth >= 2 belong to nested
            # resource declarations and must not be included.
            params << sem[j] if depth == 1 && sem[j].type != :RBRACE
            j += 1
          end
          results << { type: rtype, start: brace, end: j - 1, param_tokens: params }
          i = j
        else
          i += 1
        end
      end
      results
    end

    def find_keyword_indexes(keyword)
      results = []; sem = semantic_tokens
      sem.each_with_index do |tok, i|
        next unless tok.type == keyword
        j = i + 1
        j += 1 while j < sem.length && sem[j].type != :LBRACE
        next if j >= sem.length
        brace_start = j; depth = 1; j += 1
        while j < sem.length && depth > 0
          case sem[j].type
          when :LBRACE then depth += 1
          when :RBRACE then depth -= 1
          end
          j += 1
        end
        params = sem[(i + 1)...brace_start]
        results << {
          start: i, end: j - 1, tokens: sem[i...j],
          param_tokens: params, name_token: sem[i + 1],
        }
      end
      results
    end

    def compute_title_tokens
      results = []; sem = semantic_tokens
      sem.each_with_index do |tok, i|
        if tok.type == :LBRACE && i > 0 && sem[i - 1].type == :NAME
          j = i + 1
          results << sem[j] if j < sem.length && %i[SSTRING STRING NAME VARIABLE].include?(sem[j].type)
        end
      end
      results
    end
  end
end
