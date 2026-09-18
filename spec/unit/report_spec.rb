# frozen_string_literal: true

require 'spec_helper'
require 'csv'

RSpec.describe OpenvoxLint::Report do
  def report_for(format)
    config = OpenvoxLint::Configuration.new
    config.log_format = format
    described_class.new(config)
  end

  def format_problems(format, problems)
    io = StringIO.new
    report_for(format).format(problems, io: io)
    io.string
  end

  def sample_problem(overrides = {})
    {
      path: 'manifests/init.pp',
      line: 5,
      column: 15,
      kind: :error,
      check: :legacy_facts,
      message: "legacy fact 'osfamily'",
    }.merge(overrides)
  end

  describe '#format_github' do
    it 'emits a single workflow command for a benign problem' do
      output = format_problems('github', [sample_problem])
      expect(output.lines.size).to eq(1)
      expect(output).to eq(
        "::error file=manifests/init.pp,line=5,col=15::legacy_facts: legacy fact 'osfamily'\n"
      )
    end

    it 'does not allow newlines in the message to inject a second workflow command' do
      output = format_problems('github', [
        sample_problem(message: "hello\n::warning file=injected.pp,line=1,col=1::pwned"),
      ])
      expect(output.lines.size).to eq(1)
      expect(output).to start_with('::error ')
      expect(output).not_to include("\n::warning")
      expect(output).to include('%0A')
    end

    it 'does not allow %0A/%0D in the path or message to inject a workflow command' do
      output = format_problems('github', [
        sample_problem(
          path: "evil.pp%0A::error file=pwned.pp,line=1,col=1",
          message: "x%0A::warning file=injected.pp%0D::set-output name=x::1",
        ),
      ])
      expect(output.lines.size).to eq(1)
      expect(output).to start_with('::error file=')
      expect(output.scan(/(?<!\w)::(?:error|warning|set-output)/).size).to eq(1)
      expect(output).to include('%250A')
      expect(output).to include('%250D')
      expect(output).to include('%3A%3A')
      expect(output).not_to include('::set-output')
      expect(output).not_to include("\n::")
    end

    it 'encodes :: in the path and message so a new command cannot start' do
      output = format_problems('github', [
        sample_problem(
          path: 'foo::bar.pp',
          message: 'see ::error file=other.pp',
        ),
      ])
      expect(output.lines.size).to eq(1)
      expect(output).to start_with('::error ')
      expect(output).not_to include('file=foo::bar.pp')
      expect(output).not_to include('::error file=other.pp')
      expect(output).to include('%3A%3A')
    end

    it 'encodes commas and colons in the file property' do
      output = format_problems('github', [
        sample_problem(path: 'a,b:c.pp'),
      ])
      expect(output).to include('file=a%2Cb%3Ac.pp')
    end
  end

  describe '#format_csv' do
    it 'quotes and escapes commas, quotes, and newlines in the message' do
      output = format_problems('csv', [
        sample_problem(message: "say \"hi\", please\nnext"),
      ])
      rows = CSV.parse(output, headers: true)
      expect(rows.size).to eq(1)
      expect(rows[0]['path']).to eq('manifests/init.pp')
      expect(rows[0]['message']).to eq("say \"hi\", please\nnext")
    end
  end
end
