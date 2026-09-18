# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'stringio'
require 'tmpdir'

RSpec.describe 'CLI/UX remediations' do
  def capture_cli(args)
    stdout = StringIO.new
    stderr = StringIO.new
    status = nil
    begin
      $stdout = stdout
      $stderr = stderr
      status = OpenvoxLint::CLI.new(args.dup).run
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = STDOUT
      $stderr = STDERR
    end
    [status, stdout.string, stderr.string]
  end

  def sample_problem(path)
    {
      path: path,
      line: 5,
      column: 15,
      kind: :warning,
      check: :unquoted_file_mode,
      message: 'unquoted file mode',
    }
  end

  describe '--relative path output' do
    it 'emits paths relative to Dir.pwd when relative is true' do
      Dir.mktmpdir do |dir|
        rel = File.join('manifests', 'init.pp')
        abs = File.join(dir, rel)
        config = OpenvoxLint::Configuration.new
        config.relative = true
        io = StringIO.new
        Dir.chdir(dir) do
          OpenvoxLint::Report.new(config).format([sample_problem(abs)], io: io)
        end
        expect(io.string).to include("#{rel}:5:15:")
        expect(io.string).not_to include(dir)
      end
    end

    it 'emits the original path when relative is false' do
      abs = File.expand_path(File.join('tmp', 'abs-lint', 'manifests', 'init.pp'))
      config = OpenvoxLint::Configuration.new
      config.relative = false
      io = StringIO.new
      OpenvoxLint::Report.new(config).format([sample_problem(abs)], io: io)
      expect(io.string).to include(abs)
    end

    it 'applies relative paths to custom log format output' do
      Dir.mktmpdir do |dir|
        rel = File.join('manifests', 'init.pp')
        abs = File.join(dir, rel)
        config = OpenvoxLint::Configuration.new
        config.relative = true
        config.log_format = 'custom'
        config.custom_log_format = '%{path}:%{KIND}:%{message}'
        io = StringIO.new
        Dir.chdir(dir) do
          OpenvoxLint::Report.new(config).format([sample_problem(abs)], io: io)
        end
        expect(io.string).to eq("#{rel}:WARNING:unquoted file mode\n")
      end
    end
  end

  describe 'invalid -f / --format' do
    it 'exits 1 and names valid formats for an unknown -f value' do
      status, _out, err = capture_cli(['-f', 'xml'])
      expect(status).to eq(1)
      expect(err).to include("invalid format 'xml'")
      expect(err).to include('text, json, csv, github, codeclimate')
    end

    it 'rejects -f custom (custom is only via --log-format)' do
      status, _out, err = capture_cli(['-f', 'custom'])
      expect(status).to eq(1)
      expect(err).to include("invalid format 'custom'")
    end

    it 'accepts a named -f value' do
      status, out, err = capture_cli(['-f', 'text', '--list-checks'])
      expect(status).to eq(0)
      expect(err).not_to include('invalid format')
      expect(out).to include('Available checks')
    end
  end

  describe '--list-checks and --help' do
    it 'includes name, severity, and description for built-in checks' do
      status, out, _err = capture_cli(['--list-checks'])
      expect(status).to eq(0)
      expect(out).to match(/trailing_whitespace\s+warning\s+.+trailing whitespace/)
      expect(out).to match(/hiera3_function\s+error\s+.+Hiera 3/)
      expect(out).to match(/import_statement\s+error\s+/)
      expect(out).to match(/duplicate_params\s+error\s+/)
    end

    it 'documents --no-<check_name>-check in --help' do
      status, out, err = capture_cli(['--help'])
      help = out + err
      expect(status).to eq(0)
      expect(help).to include('--no-<check_name>-check')
      expect(help).to include('--list-checks')
    end
  end

  describe 'RC --log-format wiring' do
    def load_rc(contents)
      Dir.mktmpdir do |dir|
        path = File.join(dir, '.openvox-lint.rc')
        File.write(path, contents)
        config = OpenvoxLint::Configuration.new
        config.load_from_rc(path)
        yield config
      end
    end

    it 'treats a placeholder string as a custom format and produces custom output' do
      load_rc("--log-format %{path}:%{KIND}:%{message}\n") do |config|
        expect(config.log_format).to eq('custom')
        expect(config.custom_log_format).to eq('%{path}:%{KIND}:%{message}')
        io = StringIO.new
        OpenvoxLint::Report.new(config).format([sample_problem('foo.pp')], io: io)
        expect(io.string).to eq("foo.pp:WARNING:unquoted file mode\n")
      end
    end

    it 'accepts a named format via RC --log-format' do
      load_rc("--log-format json\n") do |config|
        expect(config.log_format).to eq('json')
        expect(config.custom_log_format).to be_nil
      end
    end

    it 'accepts --format in RC the same way as CLI -f' do
      load_rc("--format github\n") do |config|
        expect(config.log_format).to eq('github')
      end
    end

    it 'ignores an unknown --format value in RC' do
      load_rc("--format xml\n") do |config|
        expect(config.log_format).to eq('text')
      end
    end
  end
end
