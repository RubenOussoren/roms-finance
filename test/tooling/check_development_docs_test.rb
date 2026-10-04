require "minitest/autorun"
require "tmpdir"
require "fileutils"
load File.expand_path("../../bin/check-development-docs", __dir__)

class DevelopmentDocsCheckTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("development-docs")
    source = Pathname(__dir__).join("../..").expand_path
    files = DevelopmentDocsCheck::DOCUMENTS.map { |path| source.join(path) }
    files += source.glob(".skills/**/*").select(&:file?)
    files += source.glob(".cursor/rules/*.mdc")
    files.each do |file|
      target = Pathname(@root).join(file.relative_path_from(source))
      FileUtils.mkdir_p(target.parent)
      FileUtils.cp(file, target)
    end
    DevelopmentDocsCheck::ADAPTERS.each do |path, target|
      file = Pathname(@root).join(path)
      FileUtils.mkdir_p(file.parent)
      File.symlink(target, file)
    end
    # Shared docs also link to existing application/reference files outside the check scope.
    files.each do |file|
      file.read.scan(/\[[^\]\n]*\]\(([^\s)]+)\)/).flatten.each do |link|
        next if link.start_with?("#") || link.match?(/\A[a-z][a-z0-9+.-]*:/i) && !link.start_with?("mdc:")

        relative = if link.start_with?("mdc:")
          Pathname(link.delete_prefix("mdc:").split("#", 2).first)
        else
          file.parent.relative_path_from(source).join(link.split("#", 2).first).cleanpath
        end
        target = Pathname(@root).join(relative)
        next if target.exist? || !source.join(relative).exist?

        FileUtils.mkdir_p(target.parent)
        source.join(relative).directory? ? FileUtils.mkdir_p(target) : FileUtils.touch(target)
      end
    end
    @check = DevelopmentDocsCheck.new(@root)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_valid_foundation
    assert @check.run, @check.errors.join("\n")
  end

  def test_copied_adapter_is_rejected
    File.unlink(File.join(@root, "CLAUDE.md"))
    File.write(File.join(@root, "CLAUDE.md"), "Copied rules")
    refute @check.run
    assert @check.errors.any? { |error| error.include?("expected symlink") }
  end

  def test_wrong_skill_adapter_is_rejected
    file = File.join(@root, ".claude/skills")
    File.unlink(file)
    File.symlink("../missing", file)
    refute @check.run
  end

  def test_missing_skill_is_rejected
    File.unlink(File.join(@root, ".skills/test/SKILL.md"))
    refute @check.run
    assert @check.errors.any? { |error| error.include?("Skill inventory differs") }
  end

  def test_invalid_metadata_is_rejected
    File.write(File.join(@root, ".skills/test/SKILL.md"), "---\nname: [\n---\n")
    refute @check.run
    assert @check.errors.any? { |error| error.include?("invalid YAML") }
  end

  def test_wrong_skill_name_is_rejected
    File.write(File.join(@root, ".skills/test/SKILL.md"), "---\nname: other\ndescription: Test\n---\n")
    refute @check.run
    assert @check.errors.any? { |error| error.include?("name must match") }
  end

  def test_broken_markdown_and_cursor_links_are_rejected
    File.open(File.join(@root, "AGENTS.md"), "a") { |file| file.puts "\n[missing](absent.md)\n[missing cursor](mdc:absent.md)" }
    refute @check.run
    assert_equal 2, @check.errors.count { |error| error.include?("broken local link") }
  end

  def test_external_anchors_and_code_examples_are_ignored
    File.open(File.join(@root, "AGENTS.md"), "a") do |file|
      file.puts "\n[external](https://example.com/absent) [anchor](#absent)\n```md\n[example](absent.md)\n```\n"
    end
    assert @check.run, @check.errors.join("\n")
  end

  def test_missing_contextual_cursor_rule_is_rejected
    File.unlink(File.join(@root, ".cursor/rules/testing.mdc"))
    refute @check.run
    assert @check.errors.any? { |error| error.include?("Cursor routing inventory differs") }
  end

  def test_contextual_cursor_rule_needs_globs
    File.write(File.join(@root, ".cursor/rules/testing.mdc"), "---\ndescription: Tests\nalwaysApply: false\n---\n")
    refute @check.run
    assert @check.errors.any? { |error| error.include?("missing contextual globs") }
  end

  def test_repeated_runs_clear_previous_errors
    file = File.join(@root, "CLAUDE.md")
    File.unlink(file)
    refute @check.run
    File.symlink("AGENTS.md", file)
    assert @check.run, @check.errors.join("\n")
  end
end
