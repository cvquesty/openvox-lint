# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openvox-lint/version'

Gem::Specification.new do |spec|
  spec.name          = 'openvox-lint'
  spec.version       = OpenvoxLint::VERSION
  spec.authors       = ['Jerald Sheets']
  spec.email         = ['jsheets@xai.com']

  spec.summary       = 'Check OpenVox/Puppet manifests against the OpenVox Language Style Guide'
  spec.description   = <<~DESC
    openvox-lint is a modern style-guide linter for OpenVox and Puppet manifests.
    It checks your .pp files against the OpenVox Language Style Guide (the
    current canonical reference) and catches common errors, deprecated patterns
    (legacy facts, Hiera 3, import, etc.), strict-mode issues, and Puppet 8+ /
    OpenVox 8.x problems. Includes real --fix support for many checks.

    Fully compatible with OpenVox 8.x and Puppet 8.x. Drop-in replacement for
    the archived puppet-lint with better Ruby 2.5+ support and OpenVox-specific
    checks.
  DESC
  spec.homepage      = 'https://github.com/cvquesty/openvox-lint'
  spec.license       = 'Apache-2.0'

  spec.required_ruby_version = '>= 2.5.0'

  spec.metadata = {
    'homepage_uri'    => spec.homepage,
    'source_code_uri' => spec.homepage,
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'changelog_uri'   => "#{spec.homepage}/blob/development/CHANGELOG.md",
    'rubygems_mfa_required' => 'true',
  }

  spec.files = Dir[
    'lib/**/*',
    'bin/*',
    'LICENSE',
    'README.md',
    'CHANGELOG.md',
    'DOCUMENTATION.md',
  ]
  spec.bindir        = 'bin'
  spec.executables   = ['openvox-lint']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake',    '~> 13.0'
  spec.add_development_dependency 'rspec',   '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
end
