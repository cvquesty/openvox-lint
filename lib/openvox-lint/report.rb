# frozen_string_literal: true

require 'json'

module OpenvoxLint
  # Formats and outputs lint problems in the requested format.
  class Report
    SEVERITIES = { warning: 'WARNING', error: 'ERROR' }.freeze

    def initialize(configuration)
      @config = configuration
    end

    def format(problems, io: $stdout)
      case @config.log_format
      when 'json'        then format_json(problems, io)
      when 'csv'         then format_csv(problems, io)
      when 'github'      then format_github(problems, io)
      when 'codeclimate' then format_codeclimate(problems, io)
      when 'custom'      then format_custom(problems, io)
      else                    format_text(problems, io)
      end
    end

    private

    def format_text(problems, io)
      problems.each do |p|
        severity = SEVERITIES[p[:kind]] || p[:kind].to_s.upcase
        parts = []
        parts << p[:path] if @config.with_filename
        parts << p[:line].to_s
        parts << p[:column].to_s if @config.column && p[:column]
        io.puts "#{parts.join(':')}: #{severity}: #{p[:check]}: #{p[:message]}"
      end
    end

    def format_json(problems, io)
      io.puts JSON.pretty_generate(problems.map { |p| serialise(p) })
    end

    def format_csv(problems, io)
      io.puts 'path,line,column,kind,check,message'
      problems.each do |p|
        io.puts [
          csv_escape(p[:path]),
          csv_escape(p[:line]),
          csv_escape(p[:column]),
          csv_escape(p[:kind]),
          csv_escape(p[:check]),
          csv_escape(p[:message]),
        ].join(',')
      end
    end

    def format_github(problems, io)
      problems.each do |p|
        kind = p[:kind] == :error ? 'error' : 'warning'
        file = github_escape_property(p[:path])
        line = github_escape_property(p[:line])
        col = github_escape_property(p[:column])
        message = github_escape_data("#{p[:check]}: #{p[:message]}")
        io.puts "::#{kind} file=#{file},line=#{line},col=#{col}::#{message}"
      end
    end

    def format_codeclimate(problems, io)
      issues = problems.map do |p|
        {
          type: 'issue', check_name: p[:check].to_s,
          description: p[:message], categories: ['Style'],
          severity: p[:kind] == :error ? 'major' : 'minor',
          location: { path: p[:path], lines: { begin: p[:line], end: p[:line] } },
        }
      end
      io.puts JSON.pretty_generate(issues)
    end

    def format_custom(problems, io)
      fmt = @config.custom_log_format
      problems.each do |p|
        line = fmt.dup
        { '%{path}' => p[:path], '%{line}' => p[:line], '%{column}' => p[:column],
          '%{KIND}' => SEVERITIES[p[:kind]] || p[:kind].to_s.upcase,
          '%{kind}' => p[:kind], '%{check}' => p[:check],
          '%{message}' => p[:message] }.each { |k, v| line.gsub!(k, v.to_s) }
        io.puts line
      end
    end

    def serialise(p)
      { path: p[:path], line: p[:line], column: p[:column],
        kind: p[:kind].to_s, check: p[:check].to_s, message: p[:message] }
    end

    # GitHub workflow-command escaping:
    # https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-error-message
    # Encode '%' first so attacker-supplied %0A/%0D cannot decode back to newlines.
    def github_escape_data(value)
      value.to_s.gsub('%', '%25').gsub("\r", '%0D').gsub("\n", '%0A').gsub('::', '%3A%3A')
    end

    def github_escape_property(value)
      github_escape_data(value).gsub(':', '%3A').gsub(',', '%2C')
    end

    def csv_escape(value)
      s = value.to_s
      if s.match?(/[",\r\n]/)
        %("#{s.gsub('"', '""')}")
      else
        s
      end
    end
  end
end
