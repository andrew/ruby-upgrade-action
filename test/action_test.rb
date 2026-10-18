require 'test/unit'
require 'yaml'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

class ActionTest < Test::Unit::TestCase
  ACTION = YAML.load_file(File.expand_path('../action.yml', __dir__))
  TARGET = '4.0.7'
  STABLE_BUNDLER = '4.0.22'

  def setup
    @directory = Dir.mktmpdir('ruby-upgrade-action-test')
    @repository = File.join(@directory, 'repository')
    @bin = File.join(@directory, 'bin')
    FileUtils.mkdir_p([@repository, @bin])
    @env = {
      'TARGET_RUBY_VERSION' => TARGET,
      'DOCKERFILE_LOCATION' => 'Dockerfile',
      'GITHUB_OUTPUT' => File.join(@directory, 'output'),
      'COMMAND_LOG' => File.join(@directory, 'commands'),
      'GEM_HOME' => File.join(@directory, 'gems'),
      'GEM_PATH' => File.join(@directory, 'gems'),
      'GIT_CONFIG_GLOBAL' => File::NULL,
      'GIT_CONFIG_NOSYSTEM' => '1',
      'PATH' => "#{@bin}:#{File.dirname(RbConfig.ruby)}:#{ENV.fetch('PATH')}"
    }
    stub_command('gem', 'printf "gem %s\n" "$*" >> "$COMMAND_LOG"')
    stub_command('bundle', <<~SH)
      printf 'bundle %s\n' "$*" >> "$COMMAND_LOG"
      printf 'BUNDLED WITH\n   4.0.22\n' > Gemfile.lock
    SH
    stub_command('gh', 'printf "gh %s\n" "$*" >> "$COMMAND_LOG"')
    FileUtils.mkdir_p(File.join(@env['GEM_HOME'], 'specifications'))
    [STABLE_BUNDLER, '4.1.0.beta2'].each do |version|
      File.write(File.join(@env['GEM_HOME'], 'specifications', "bundler-#{version}.gemspec"), <<~RUBY)
        Gem::Specification.new do |spec|
          spec.name = 'bundler'
          spec.version = '#{version}'
          spec.summary = 'Bundler test fixture'
          spec.authors = ['Test']
        end
      RUBY
    end
    command('git', 'init', '-b', 'main')
    command('git', 'config', 'user.name', 'Test')
    command('git', 'config', 'user.email', 'test@example.com')
    remote = File.join(@directory, 'remote.git')
    command('git', 'init', '--bare', remote)
    command('git', 'remote', 'add', 'origin', remote)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_current_versions_preserve_formatting_and_skip_pr
    files = {
      '.ruby-version' => TARGET,
      '.tool-versions' => "ruby\t#{TARGET}\nnodejs 22.0.0\n",
      'Gemfile' => "source 'https://rubygems.org'\nruby \"#{TARGET}\"\n",
      'Dockerfile' => "FROM ruby:#{TARGET}-slim AS app\n"
    }
    checkout(files)
    run_action
    assert_no_pr
    files.each { |path, content| assert_equal(content, File.read(File.join(@repository, path))) }
    assert_equal('', command('git', 'status', '--porcelain'))
  end

  def test_dependency_changes_do_not_trigger_pr
    checkout('Gemfile' => "ruby '#{TARGET}'\ngem 'rake'\n", 'Gemfile.lock' => "old dependencies\n")
    File.write(File.join(@repository, 'Gemfile.lock'), "updated dependencies\n")
    File.write(File.join(@repository, 'Gemfile'), "ruby '#{TARGET}'\ngem 'rake', '>= 13'\n")
    File.write(File.join(@repository, 'unrelated.txt'), 'unrelated change')
    run_action
    assert_no_pr
  end

  def test_bundler_only_change_does_not_trigger_pr
    checkout('Gemfile' => "ruby '#{TARGET}'\n", 'Gemfile.lock' => "BUNDLED WITH\n   4.0.21\n")
    File.write(File.join(@repository, 'Gemfile.lock'), "BUNDLED WITH\n   #{STABLE_BUNDLER}\n")
    run_action
    assert_no_pr
  end

  data(
    'ruby-version' => ['.ruby-version', "4.0.6\n", "#{TARGET}\n"],
    'tool-versions' => ['.tool-versions', "ruby 4.0.6\nnodejs 22.0.0\n", "ruby #{TARGET}\nnodejs 22.0.0\n"],
    'Gemfile' => ['Gemfile', "ruby \"4.0.6\"\n", "ruby \"#{TARGET}\"\n"],
    'Dockerfile' => ['Dockerfile', "FROM ruby:4.0.6-slim AS app\n", "FROM ruby:#{TARGET}-slim AS app\n"]
  )
  def test_ruby_changes_trigger_pr(values)
    path, original, expected = values
    checkout(path => original)
    run_action
    assert_equal("has_changes=true\n", File.read(@env['GITHUB_OUTPUT']))
    assert_equal(expected, File.read(File.join(@repository, path)))
    assert_include(command_log, 'gh pr create')
    assert_equal("Update Ruby to version #{TARGET}\n", command('git', 'log', '-1', '--format=%s'))
    assert_equal('', command('git', 'status', '--porcelain'))
    assert_equal(command('git', 'rev-parse', 'HEAD'), command('git', 'rev-parse', 'origin/ruby-version-upgrade'))
  end

  def test_custom_dockerfile_location
    @env['DOCKERFILE_LOCATION'] = 'docker/Dockerfile'
    checkout(@env['DOCKERFILE_LOCATION'] => "FROM ruby:4.0.6-alpine\n")
    run_action
    assert_equal("FROM ruby:#{TARGET}-alpine\n", File.read(File.join(@repository, @env['DOCKERFILE_LOCATION'])))
    assert_include(command_log, 'gh pr create')
  end

  def test_gemfile_without_ruby_declaration_does_not_trigger_pr
    checkout('Gemfile' => "source 'https://rubygems.org'\ngem 'rake'\n")
    run_action
    assert_no_pr
  end

  def test_bundler_uses_stable_version_even_with_beta_installed
    checkout('.ruby-version' => "4.0.6\n", 'Gemfile' => "ruby file: '.ruby-version'\n")
    run_action
    assert_include(command_log, 'gem install bundler --no-document --no-prerelease')
    assert_equal([
      "bundle _#{STABLE_BUNDLER}_ update --bundler=#{STABLE_BUNDLER}",
      "bundle _#{STABLE_BUNDLER}_ install",
      "bundle _#{STABLE_BUNDLER}_ update --ruby"
    ], command_log.lines.map(&:chomp).grep(/^bundle /))
    assert_equal("BUNDLED WITH\n   #{STABLE_BUNDLER}\n", File.read(File.join(@repository, 'Gemfile.lock')))
  end

  def checkout(files)
    files.each do |path, content|
      full_path = File.join(@repository, path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end
    command('git', 'add', '.')
    command('git', 'commit', '-m', 'Initial files')
  end

  def run_action
    steps = ACTION.fetch('runs').fetch('steps').drop_while { |step| step['name'] != 'Create upgrade branch' }
    steps.each_with_index do |step, index|
      if step['if']
        assert_equal("steps.check_changes.outputs.has_changes == 'true'", step['if'])
        next unless File.read(@env['GITHUB_OUTPUT']).include?("has_changes=true\n")
      end
      script = step.fetch('run').gsub('${{ env.TARGET_RUBY_VERSION }}', TARGET)
        .gsub('${{ inputs.branch-name }}', 'ruby-version-upgrade')
        .gsub('${{ inputs.dockerfile-location }}', @env['DOCKERFILE_LOCATION'])
      path = File.join(@directory, "step-#{index}")
      File.write(path, script)
      if step['shell'] == 'ruby {0}'
        command(RbConfig.ruby, path)
      else
        assert_equal('bash', step['shell'])
        command('bash', '--noprofile', '--norc', '-eo', 'pipefail', path)
      end
    end
  end

  def assert_no_pr
    assert_equal("has_changes=false\n", File.read(@env['GITHUB_OUTPUT']))
    assert_equal('', command_log)
    assert_equal("Initial files\n", command('git', 'log', '-1', '--format=%s'))
    assert_equal('', command('git', 'ls-remote', '--heads', 'origin'))
  end

  def command_log
    File.exist?(@env['COMMAND_LOG']) ? File.read(@env['COMMAND_LOG']) : ''
  end

  def stub_command(name, script)
    path = File.join(@bin, name)
    File.write(path, "#!/bin/bash\nset -e\n#{script}\n")
    File.chmod(0o755, path)
  end

  def command(*arguments)
    output, status = Open3.capture2e(@env, *arguments, chdir: @repository)
    assert(status.success?, "#{arguments.join(' ')} failed:\n#{output}")
    output
  end
end
