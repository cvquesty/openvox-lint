# frozen_string_literal: true

require 'optparse'

module OpenvoxLint
  # Command-line interface for openvox-lint.
  class CLI
    def initialize(args = ARGV)
      @args = args
    end

    def run
      OpenvoxLint.reset_configuration!
      @config = OpenvoxLint.configuration
      parse_options
      load_rc_file
      if @list_checks
        list_checks; return 0
      end
      files = @args.empty? ? ['.'] : @args
      linter = Linter.new(configuration: @config)
      linter.run(*files)
      Report.new(@config).format(linter.problems)
      print_summary(linter) unless @config.log_format == 'json'
      linter.exit_code
    end

    private

    def parse_options # rubocop:disable Metrics/MethodLength
      @parser = OptionParser.new do |opts|
        opts.banner = "Usage: openvox-lint [options] [file|directory ...]"
        opts.separator ''; opts.separator 'Options:'
        opts.on('--version', 'Display version') { puts "openvox-lint #{VERSION}"; exit 0 }
        opts.on('-f', '--format FORMAT', 'Output format: text json csv github codeclimate') { |f| @config.log_format = f }
        opts.on('--log-format FORMAT', 'Custom log format string') { |f| @config.custom_log_format = f; @config.log_format = 'custom' }
        opts.on('--fix', 'Automatically fix problems') { @config.fix = true }
        opts.on('--fail-on-warnings', 'Exit 1 on warnings') { @config.fail_on_warnings = true }
        opts.on('--no-filename', 'Suppress filename') { @config.with_filename = false }
        opts.on('--no-column', 'Suppress column') { @config.column = false }
        opts.on('--relative', 'Relative paths') { @config.relative = true }
        opts.on('--only-checks CHECKS', 'Comma-separated checks') { |c| @config.only_checks = c.split(',').map { |s| s.strip.to_sym } }
        opts.on('--ignore-paths PATHS', 'Comma-separated globs') { |p| @config.ignore_paths = p.split(',').map(&:strip) }
        opts.on('--list-checks', 'List available checks') { @list_checks = true }
        opts.on('-c', '--config FILE', 'Config file path') { |f| @explicit_config_file = f }
      end
      remaining = []
      begin
        @parser.order!(@args) { |a| remaining << a }
      rescue OptionParser::InvalidOption => e
        flag = e.args.first
        if flag =~ /\A--no-(.+)-check\z/
          @config.disabled_checks << Regexp.last_match(1).tr('-', '_').to_sym
        else
          $stderr.puts e.message; exit 1
        end
        retry
      end
      @args.replace(remaining)
    end

    def load_rc_file
      # Priority: explicit --config flag > local .openvox-lint.rc > ~/.openvox-lint.rc
      # An explicit --config flag must always win.  The default value of
      # config_file is nil until the user passes -c / --config.
      candidates = if @explicit_config_file
                     [@explicit_config_file]
                   else
                     ['.openvox-lint.rc', File.expand_path('~/.openvox-lint.rc')]
                   end
      candidates.each do |path|
        next unless path && File.exist?(path)
        @config.load_from_rc(path); break
      end
    end

    def list_checks
      puts "Available checks (#{OpenvoxLint.checks.size} total):"; puts ''
      OpenvoxLint.checks.keys.sort.each do |name|
        puts "  #{@config.check_enabled?(name) ? '✓' : '✗'}  #{name}"
      end
    end

    def print_summary(linter)
      w = linter.problems.count { |p| p[:kind] == :warning }
      e = linter.problems.count { |p| p[:kind] == :error }
      t = linter.problems.size; f = linter.file_count
      $stderr.puts ''
      if t == 0
        $stderr.puts "✓ #{f} file(s) checked — no problems found."
      else
        $stderr.puts "#{f} file(s) checked — #{t} problem(s) found (#{e} error(s), #{w} warning(s))."
      end
    end
  end
end
