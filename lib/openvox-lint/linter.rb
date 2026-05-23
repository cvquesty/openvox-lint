# frozen_string_literal: true

module OpenvoxLint
  # Orchestrates the linting of one or more manifest files.
  class Linter
    attr_reader :problems, :file_count

    def initialize(configuration: OpenvoxLint.configuration)
      @config     = configuration
      @problems   = []
      @file_count = 0
    end

    def run(*fileargs)
      files = expand_files(fileargs.flatten)
      files.each { |f| lint_file(f) }
      @problems.sort_by! { |p| [p[:path] || '', p[:line] || 0, p[:column] || 0] }
    end

    def errors?
      @problems.any? { |p| p[:kind] == :error }
    end

    def warnings?
      @problems.any? { |p| p[:kind] == :warning }
    end

    def exit_code
      return 1 if errors?
      return 1 if warnings? && @config.fail_on_warnings
      0
    end

    private

    def lint_file(filepath)
      @file_count += 1
      code = File.read(filepath)
      lexer = Lexer.new(code)
      checker = Checks.new(
        tokens: lexer.tokens, manifest_lines: lexer.manifest_lines,
        fullpath: filepath, configuration: @config,
      )
      @problems.concat(checker.run)

      # Apply --fix: checks' #fix methods (if implemented) mutate the shared
      # manifest_lines array in place. After all checks, write the (possibly
      # fixed) content back if it differs. This makes --fix functional for
      # supported checks. Ensures final newline per style guide.
      if @config.fix
        begin
          fixed_code = lexer.manifest_lines.join("\n") + "\n"
          if fixed_code != code
            File.write(filepath, fixed_code)
          end
        rescue StandardError => write_err
          @problems << {
            path: filepath, line: 0, column: 0, kind: :error,
            check: :fix, message: "Failed to write fixes: #{write_err.message}",
          }
        end
      end
    rescue StandardError => e
      @problems << {
        path: filepath, line: 0, column: 0, kind: :error,
        check: :syntax, message: "Could not parse file: #{e.message}",
      }
    end

    def expand_files(fileargs)
      files = []
      fileargs.each do |arg|
        if File.directory?(arg)
          files.concat(Dir.glob(File.join(arg, '**', '*.pp')))
        elsif arg.include?('*')
          files.concat(Dir.glob(arg))
        elsif File.file?(arg)
          files << arg
        end
      end
      files.reject { |f| ignored?(f) }.uniq
    end

    def ignored?(filepath)
      # Normalize away leading './' so that patterns like 'vendor/**/*.pp'
      # match regardless of whether the file was discovered as
      # './vendor/foo.pp' or 'vendor/foo.pp'.
      normalized = filepath.sub(%r{\A\./}, '')
      @config.ignore_paths.any? do |pat|
        File.fnmatch?(pat, normalized, File::FNM_PATHNAME | File::FNM_DOTMATCH) ||
          File.fnmatch?(pat, filepath, File::FNM_PATHNAME | File::FNM_DOTMATCH) ||
          File.fnmatch?("**/#{pat}", normalized, File::FNM_PATHNAME | File::FNM_DOTMATCH)
      end
    end
  end
end
