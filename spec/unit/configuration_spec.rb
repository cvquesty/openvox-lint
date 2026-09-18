# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpenvoxLint::Configuration do
  def write_rc(dir, name, contents)
    path = File.join(dir, name)
    File.write(path, contents)
    path
  end

  it 'does not enable fix when the RC file contains --fix' do
    Dir.mktmpdir do |dir|
      rc = write_rc(dir, 'rc', "--fix\n--fail-on-warnings\n")
      config = described_class.new
      expect(config.fix).to eq(false)
      stderr = StringIO.new
      original = $stderr
      $stderr = stderr
      begin
        config.load_from_rc(rc)
      ensure
        $stderr = original
      end
      expect(config.fix).to eq(false)
      expect(config.fail_on_warnings).to eq(true)
      expect(stderr.string).to include('ignoring --fix from RC file')
    end
  end

  it 'honors --no-fix from an RC file' do
    Dir.mktmpdir do |dir|
      rc = write_rc(dir, 'rc', "--no-fix\n")
      config = described_class.new
      config.fix = true
      config.load_from_rc(rc)
      expect(config.fix).to eq(false)
    end
  end
end
