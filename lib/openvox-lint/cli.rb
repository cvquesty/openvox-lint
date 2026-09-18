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
      # Precedence: defaults < user RC < project RC < CLI. Load RC first so
      # OptionParser overrides it. --config is peeked so an explicit file is
      # used during that load; --fix from RC is ignored (see Configuration).
      @explicit_config_file = peek_explicit_config_file
      load_rc_file
      parse_options
      if @list_checks
        list_checks; return 0
      end
      files = @args.empty? ? ['.'] : @args
      linter = Linter.new(configuration: @config)
      begin
        linter.run(*files)
      rescue OpenvoxLint::Error => e
        $stderr.puts "openvox-lint: #{e.message}"
        return 1
      end
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
        opts.on('-f', '--format FORMAT', 'Output format: text json csv github codeclimate') { |f| apply_cli_format(f) }
        opts.on('--log-format FORMAT', 'Custom log format string') { |f| @config.custom_log_format = f; @config.log_format = 'custom' }
        opts.on('--[no-]fix', 'Automatically fix problems (CLI only; RC cannot enable)') { |v| @config.fix = v }
        opts.on('--fail-on-warnings', 'Exit 1 on warnings') { @config.fail_on_warnings = true }
        opts.on('--no-filename', 'Suppress filename') { @config.with_filename = false }
        opts.on('--no-column', 'Suppress column') { @config.column = false }
        opts.on('--relative', 'Display paths relative to the current working directory') { @config.relative = true }
        opts.on('--only-checks CHECKS', 'Comma-separated checks') { |c| @config.only_checks = c.split(',').map { |s| s.strip.to_sym } }
        opts.on('--ignore-paths PATHS', 'Comma-separated globs') { |p| @config.ignore_paths = p.split(',').map(&:strip) }
        opts.on('--list-checks', 'List available checks (name, severity, description)') { @list_checks = true }
        opts.separator '    --no-<check_name>-check      Disable a check (see --list-checks)'
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

    def peek_explicit_config_file
      @args.each_with_index do |arg, idx|
        if ['-c', '--config'].include?(arg)
          return @args[idx + 1]
        elsif arg.start_with?('--config=')
          return arg.split('=', 2).last
        end
      end
      nil
    end

    def load_rc_file
      # Precedence: defaults < ~/.openvox-lint.rc (user) < .openvox-lint.rc
      # (project) < CLI. An explicit --config / -c file replaces the RC chain.
      candidates = if @explicit_config_file
                     [@explicit_config_file]
                   else
                     [File.expand_path('~/.openvox-lint.rc'), '.openvox-lint.rc']
                   end
      candidates.each do |path|
        next unless path && File.exist?(path)
        @config.load_from_rc(path)
      end
    end

    def apply_cli_format(value)
      if Configuration::NAMED_FORMATS.include?(value)
        @config.log_format = value
        return
      end
      $stderr.puts "error: invalid format '#{value}' (valid: #{Configuration::NAMED_FORMATS.join(', ')})"
      exit 1
    end

    # CheckPlugin has no severity/description API. Read them from the plugin
    # source: the kind the check passes to notify, and the file header comment.
    def list_checks
      names = OpenvoxLint.checks.keys.sort
      width = [names.map { |n| n.to_s.length }.max, 8].max
      puts "Available checks (#{names.size} total):"
      puts ''
      names.each do |name|
        klass = OpenvoxLint.checks[name]
        mark = @config.check_enabled?(name) ? '✓' : '✗'
        severity = plugin_severity(klass)
        description = plugin_description(klass)
        puts format("  %s  %-#{width}s  %-7s  %s", mark, name, severity, description).rstrip
      end
    end

    def plugin_source_file(klass)
      file, = klass.instance_method(:check).source_location
      file
    end

    def plugin_severity(klass)
      file = plugin_source_file(klass)
      return 'warning' unless file && File.file?(file)
      File.foreach(file) do |line|
        return 'error' if line =~ /notify\s+:error\b/
        return 'warning' if line =~ /notify\s+:warning\b/
      end
      'warning'
    end

    def plugin_description(klass)
      file = plugin_source_file(klass)
      return '' unless file && File.file?(file)
      lines = []
      started = false
      File.foreach(file) do |line|
        stripped = line.strip
        next if !started && (stripped.empty? ||
                             stripped == '# frozen_string_literal: true' ||
                             stripped.start_with?('require '))
        break unless stripped.start_with?('#')
        started = true
        text = stripped.sub(/\A#\s?/, '')
        break if text.empty? && !lines.empty?
        lines << text unless text.empty?
      end
      lines.join(' ')
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
