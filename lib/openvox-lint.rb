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

    def checks
      @checks ||= {}
    end

    def new_check(name, &block)
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
