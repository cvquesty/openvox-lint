# frozen_string_literal: true

require_relative 'openvox-lint/version'
require_relative 'openvox-lint/configuration'
require_relative 'openvox-lint/token'
require_relative 'openvox-lint/lexer'
require_relative 'openvox-lint/check_plugin'
require_relative 'openvox-lint/checks'
require_relative 'openvox-lint/report'
require_relative 'openvox-lint/linter'
require_relative 'openvox-lint/cli'

# OpenvoxLint – a style-guide linter for OpenVox / Puppet manifests.
#
# Compatible with:
#   - OpenVox 8.x (community fork of Puppet)
#   - Puppet 8.x
#   - Legacy Puppet 7.x manifests (with deprecation warnings)
module OpenvoxLint
  class Error < StandardError; end
  class NoFix < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Reset the global configuration singleton.  Called at the start of
    # every CLI run so that repeated invocations in the same Ruby
    # process (Vim plugins, guard, Rake loops) start clean.
    def reset_configuration!
      @configuration = Configuration.new
    end

    def checks
      @checks ||= {}
    end

    def new_check(name, &block)
      if checks.key?(name)
        $stderr.puts "openvox-lint: warning: check '#{name}' is already registered — overwriting" if ENV['OPENVOX_LINT_DEBUG']
      end
      klass = Class.new(CheckPlugin, &block)
      klass.instance_variable_set(:@check_name, name)
      checks[name] = klass
    end
  end
end

# Auto-load every built-in check plugin.
Dir[File.join(__dir__, 'openvox-lint', 'plugins', 'checks', '*.rb')].sort.each do |f|
  require f
end
