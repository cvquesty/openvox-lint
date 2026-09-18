# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe OpenvoxLint::Linter do
  def lint_path(path, fix: true)
    config = OpenvoxLint::Configuration.new
    config.fix = fix
    config.only_checks = [:trailing_whitespace]
    config.ignore_paths = []
    linter = described_class.new(configuration: config)
    linter.run(path)
    linter
  end

  it 'writes fixes to a regular file' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'manifest.pp')
      File.write(path, "class foo { }   \n")
      linter = lint_path(path)
      expect(File.read(path)).to eq("class foo { }\n")
      expect(linter.problems.any? { |p| p[:check] == :fix }).to eq(false)
    end
  end

  it 'refuses to write fixes through a symlink leaf' do
    Dir.mktmpdir do |dir|
      target = File.join(dir, 'target.pp')
      link = File.join(dir, 'link.pp')
      original = "class foo { }   \n"
      File.write(target, original)
      File.symlink(target, link)

      linter = lint_path(link)
      expect(File.read(target)).to eq(original)
      expect(File.symlink?(link)).to eq(true)
      refusal = linter.problems.find { |p| p[:check] == :fix }
      expect(refusal).not_to be_nil
      expect(refusal[:kind]).to eq(:error)
      expect(refusal[:message]).to match(/symbolic link/i)
    end
  end

  it 'refuses to write fixes when a path component is a symlink' do
    Dir.mktmpdir do |dir|
      real_dir = File.join(dir, 'real')
      link_dir = File.join(dir, 'link')
      Dir.mkdir(real_dir)
      File.symlink(real_dir, link_dir)
      path = File.join(link_dir, 'manifest.pp')
      original = "class foo { }   \n"
      File.write(File.join(real_dir, 'manifest.pp'), original)

      linter = lint_path(path)
      expect(File.read(File.join(real_dir, 'manifest.pp'))).to eq(original)
      refusal = linter.problems.find { |p| p[:check] == :fix }
      expect(refusal).not_to be_nil
      expect(refusal[:kind]).to eq(:error)
      expect(refusal[:message]).to match(/symbolic link/i)
    end
  end
end
