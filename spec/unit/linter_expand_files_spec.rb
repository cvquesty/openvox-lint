# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe OpenvoxLint::Linter, '#expand_files / #run fail-closed' do
  def linter
    config = OpenvoxLint::Configuration.new
    config.ignore_paths = []
    OpenvoxLint::Linter.new(configuration: config)
  end

  it 'raises when no args are given' do
    expect { linter.run }.to raise_error(OpenvoxLint::Error, /no files or directories/)
  end

  it 'raises when a path does not exist' do
    expect { linter.run('/nonexistent/path/foo.pp') }
      .to raise_error(OpenvoxLint::Error, /no such file or directory/)
  end

  it 'raises when a glob matches nothing' do
    Dir.mktmpdir do |dir|
      expect { linter.run(File.join(dir, '*.pp')) }
        .to raise_error(OpenvoxLint::Error, /glob matched no files/)
    end
  end

  it 'raises when a directory contains no .pp files' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'readme.txt'), 'hi')
      expect { linter.run(dir) }
        .to raise_error(OpenvoxLint::Error, /no Puppet manifests/)
    end
  end

  it 'returns non-zero via CLI when expand_files fails' do
    code = OpenvoxLint::CLI.new(['/nonexistent/nope.pp']).run
    expect(code).to eq(1)
  end

  it 'lints an existing .pp file' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'init.pp')
      File.write(path, "class foo { }\n")
      l = linter
      expect { l.run(path) }.not_to raise_error
      expect(l.file_count).to eq(1)
    end
  end
end
