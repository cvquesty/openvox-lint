# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'

RSpec.describe OpenvoxLint::CLI do
  def run_cli(args)
    stdout = StringIO.new
    stderr = StringIO.new
    old_out = $stdout
    old_err = $stderr
    $stdout = stdout
    $stderr = stderr
    code = described_class.new(args).run
    [code, stdout.string, stderr.string]
  ensure
    $stdout = old_out
    $stderr = old_err
  end

  def with_isolated_rc
    Dir.mktmpdir('ovl-home') do |home|
      Dir.mktmpdir('ovl-project') do |project|
        original_home = ENV['HOME']
        ENV['HOME'] = home
        Dir.chdir(project) do
          File.write('foo.pp', "class foo { }   \n")
          yield(home, project)
        end
      ensure
        ENV['HOME'] = original_home
      end
    end
  end

  it 'does not enable fix when RC contains --fix and the CLI does not' do
    with_isolated_rc do |_home, _project|
      File.write('.openvox-lint.rc', "--fix\n")
      run_cli(%w[--only-checks trailing_whitespace foo.pp])
      expect(OpenvoxLint.configuration.fix).to eq(false)
      expect(File.read('foo.pp')).to eq("class foo { }   \n")
    end
  end

  it 'lets CLI --fix enable writes even when RC also lists --fix' do
    with_isolated_rc do |_home, _project|
      File.write('.openvox-lint.rc', "--fix\n")
      run_cli(%w[--fix --only-checks trailing_whitespace foo.pp])
      expect(OpenvoxLint.configuration.fix).to eq(true)
      expect(File.read('foo.pp')).to eq("class foo { }\n")
    end
  end

  it 'lets CLI --no-fix disable fix after RC is loaded' do
    with_isolated_rc do |_home, _project|
      File.write('.openvox-lint.rc', "--fail-on-warnings\n")
      run_cli(%w[--fix --no-fix --only-checks trailing_whitespace foo.pp])
      expect(OpenvoxLint.configuration.fix).to eq(false)
      expect(File.read('foo.pp')).to eq("class foo { }   \n")
    end
  end

  it 'applies user RC then project RC then CLI (CLI wins)' do
    with_isolated_rc do |home, _project|
      File.write(File.join(home, '.openvox-lint.rc'), "--fail-on-warnings\n--log-format csv\n")
      File.write('.openvox-lint.rc', "--log-format json\n")
      run_cli(%w[-f text --only-checks trailing_whitespace foo.pp])
      expect(OpenvoxLint.configuration.fail_on_warnings).to eq(true)
      expect(OpenvoxLint.configuration.log_format).to eq('text')
    end
  end

  it 'loads an explicit --config file instead of the default RC chain' do
    with_isolated_rc do |_home, project|
      File.write('.openvox-lint.rc', "--fail-on-warnings\n")
      explicit = File.join(project, 'custom.rc')
      File.write(explicit, "--log-format json\n")
      run_cli(['--config', explicit, '--only-checks', 'trailing_whitespace', 'foo.pp'])
      expect(OpenvoxLint.configuration.fail_on_warnings).to eq(false)
      expect(OpenvoxLint.configuration.log_format).to eq('json')
    end
  end
end
