# frozen_string_literal: true

module OpenvoxLint
  # Holds all runtime configuration.
  class Configuration
    DEFAULTS = {
      log_format: 'text', with_filename: true, fail_on_warnings: false,
      fix: false, only_checks: [], disabled_checks: [],
      ignore_paths: %w[vendor/**/*.pp pkg/**/*.pp spec/**/*.pp],
      relative: false, column: true, custom_log_format: nil,
    }.freeze

    attr_accessor :log_format, :with_filename, :fail_on_warnings,
                  :fix, :only_checks, :disabled_checks, :ignore_paths,
                  :relative, :column, :custom_log_format

    def initialize
      DEFAULTS.each do |k, v|
        send(:"#{k}=", v.is_a?(Array) ? v.dup : v)
      end
    end

    def load_from_rc(path)
      return unless File.exist?(path)
      File.readlines(path).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        flag, value = line.split(/\s+/, 2)
        apply_flag(flag, value)
      end
    end

    def check_enabled?(name)
      name = name.to_sym
      return false if disabled_checks.include?(name)
      return only_checks.include?(name) unless only_checks.empty?
      true
    end

    private

    def apply_flag(flag, value)
      case flag
      when '--fix'              then self.fix = true
      when '--no-fix'           then self.fix = false
      when '--fail-on-warnings' then self.fail_on_warnings = true
      when /\A--no-(.+)-check\z/
        disabled_checks << Regexp.last_match(1).tr('-', '_').to_sym
      when '--only-checks'
        self.only_checks = (value || '').split(',').map { |c| c.strip.to_sym }
      when '--log-format'
        self.log_format = value&.strip || 'text'
      when '--ignore-paths'
        self.ignore_paths = (value || '').split(',').map(&:strip)
      end
    end
  end
end
