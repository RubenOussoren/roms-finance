require "minitest/autorun"
require "yaml"
require "tmpdir"
require "open3"

# Static workflow contracts plus a local git check of the resolver script.
# This is not an Actions emulator: action behavior and remote dispatch need CI evidence.
class PublishWorkflowTest < Minitest::Test
  SHA = "${{ needs.resolve.outputs.sha }}"
  PUSH_TAG = "github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')"
  PUSH_MAIN = "github.event_name == 'push' && github.ref == 'refs/heads/main'"

  def setup
    @ci = workflow("ci")
    @publish = workflow("publish")
  end

  def workflow(name)
    YAML.safe_load_file(File.expand_path("../../.github/workflows/#{name}.yml", __dir__))
  end

  def steps(job)
    @publish.fetch("jobs").fetch(job).fetch("steps")
  end

  def metadata
    steps("build").find { |step| step["id"] == "meta" }.fetch("with")
  end

  def test_optional_ci_ref_preserves_default_pr_merge_checkout
    # Psych's YAML 1.1 treats the unquoted Actions key `on` as true.
    input = @ci.fetch(true).fetch("workflow_call").fetch("inputs").fetch("checkout_ref")
    assert_equal false, input.fetch("required")
    assert_equal "string", input.fetch("type")
    assert_equal "", input.fetch("default")
  end

  def test_every_ci_checkout_uses_the_same_input
    assert_equal %w[development_docs scan_ruby scan_js lint lint_js test].sort, @ci.fetch("jobs").keys.sort
    @ci.fetch("jobs").each do |name, job|
      checkouts = job.fetch("steps").select { |step| step["uses"].to_s.start_with?("actions/checkout@") }
      refute_empty checkouts, name
      checkouts.each { |step| assert_equal "${{ inputs.checkout_ref }}", step.fetch("with").fetch("ref"), name }
    end
  end

  def test_documentation_gate_and_standalone_regressions_are_retained
    commands = @ci.fetch("jobs").fetch("development_docs").fetch("steps").filter_map { |step| step["run"] }.join("\n")
    assert_includes commands, "ruby bin/check-development-docs"
    assert_includes commands, "bundle exec ruby test/tooling/check_development_docs_test.rb"
    assert_includes commands, "bundle exec ruby test/tooling/publish_workflow_test.rb"
  end

  def test_historical_publication_compatibility_never_skips_current_pr_gate
    step = @ci.fetch("jobs").fetch("development_docs").fetch("steps").find { |entry| entry["run"] }
    assert_equal "${{ inputs.checkout_ref }}", step.fetch("env").fetch("PUBLICATION_CHECKOUT_REF")
    Dir.mktmpdir("historical-publication") do |dir|
      env = { "PUBLICATION_CHECKOUT_REF" => "a" * 40 }
      output, status = Open3.capture2e(env, "bash", "-e", "-c", step.fetch("run"), chdir: dir)
      assert status.success?, output
      assert_includes output, "predates foundation tooling"

      output, status = Open3.capture2e({ "PUBLICATION_CHECKOUT_REF" => "" }, "bash", "-e", "-c", step.fetch("run"), chdir: dir)
      refute status.success?, "PR CI must fail when foundation tooling is missing"
      refute_includes output, "::notice::"

      Dir.mkdir(File.join(dir, ".skills"))
      output, status = Open3.capture2e(env, "bash", "-e", "-c", step.fetch("run"), chdir: dir)
      refute status.success?, "Publication must fail for partially deleted foundation tooling"
      refute_includes output, "::notice::"

      output, status = Open3.capture2e({ "PUBLICATION_CHECKOUT_REF" => "" }, "bash", "-e", "-c", step.fetch("run"), chdir: dir)
      refute status.success?, "PR CI must also fail for partial tooling"
      refute_includes output, "::notice::"

      Dir.rmdir(File.join(dir, ".skills"))
      Dir.mkdir(File.join(dir, "bin"))
      File.write(File.join(dir, "bin/check-development-docs"), "abort 'Incomplete tooling fixture'\n")
      output, status = Open3.capture2e(env, "bash", "-e", "-c", step.fetch("run"), chdir: dir)
      refute status.success?, "Publication must fail when the checker exists but skills are missing"
      refute_includes output, "::notice::"
    end
  end

  def test_ci_test_budget_covers_setup_and_both_required_suites
    job = @ci.fetch("jobs").fetch("test")
    assert_equal 20, job.fetch("timeout-minutes")
    refute job.fetch("continue-on-error", false)
    required = {
      "Unit and integration tests" => "bin/rails test",
      "System tests" => "DISABLE_PARALLELIZATION=true bin/rails test:system"
    }
    required.each do |name, command|
      step = job.fetch("steps").find { |entry| entry["name"] == name }
      refute_nil step, name
      assert_equal command, step.fetch("run")
      refute step.key?("if"), "#{name} must run unconditionally after successful setup"
      refute step.fetch("continue-on-error", false), "#{name} must remain a required gate"
    end
  end

  def test_service_versions_match_sandbox
    services = @ci.fetch("jobs").fetch("test").fetch("services")
    assert_equal "postgres:16-alpine", services.fetch("postgres").fetch("image")
    assert_equal "redis:7-alpine", services.fetch("redis").fetch("image")
  end

  def test_requested_ref_is_resolved_once_without_shell_interpolation
    checkout = steps("resolve").find { |step| step["uses"].to_s.start_with?("actions/checkout@") }
    assert_equal "${{ inputs.ref || github.sha }}", checkout.fetch("with").fetch("ref")
    resolver = steps("resolve").find { |step| step["id"] == "revision" }
    assert_equal "${{ steps.revision.outputs.sha }}", @publish.fetch("jobs").fetch("resolve").fetch("outputs").fetch("sha")
    assert_includes resolver.fetch("run"), "git rev-parse HEAD"
    refute_includes resolver.fetch("run"), "${{"

    Dir.mktmpdir("publication-revision") do |dir|
      git_env = { "GIT_CONFIG_NOSYSTEM" => "1", "GIT_CONFIG_GLOBAL" => File::NULL,
                  "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.invalid",
                  "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.invalid" }
      [ [ "init", "--quiet" ], [ "commit", "--quiet", "--allow-empty", "-m", "fixture" ] ].each do |args|
        output, status = Open3.capture2e(git_env, "git", *args, chdir: dir)
        assert status.success?, output
      end
      expected, status = Open3.capture2e("git", "rev-parse", "HEAD", chdir: dir)
      assert status.success?, expected
      output_path = File.join(dir, "output")
      output, status = Open3.capture2e({ "GITHUB_OUTPUT" => output_path }, "bash", "-e", "-c", resolver.fetch("run"), chdir: dir)
      assert status.success?, output
      assert_equal "sha=#{expected.strip}\n", File.read(output_path)
    end
  end

  def test_ci_and_build_depend_on_and_checkout_resolved_identity
    ci = @publish.fetch("jobs").fetch("ci")
    assert_equal [ "resolve" ], ci.fetch("needs")
    assert_equal "./.github/workflows/ci.yml", ci.fetch("uses")
    assert_equal SHA, ci.fetch("with").fetch("checkout_ref")
    assert_equal %w[resolve ci], @publish.fetch("jobs").fetch("build").fetch("needs")
    checkouts = steps("build").select { |step| step["uses"].to_s.start_with?("actions/checkout@") }
    assert_equal 1, checkouts.size
    assert_equal SHA, checkouts.first.fetch("with").fetch("ref")
  end

  def test_image_tag_revision_and_build_argument_use_resolved_identity
    assert_includes metadata.fetch("tags").lines.map(&:strip), "type=raw,value=sha-#{SHA}"
    assert_equal "org.opencontainers.image.revision=#{SHA}", metadata.fetch("labels").strip
    build = steps("build").find { |step| step["id"] == "build" }.fetch("with")
    assert_equal "BUILD_COMMIT_SHA=#{SHA}", build.fetch("build-args")
    assert_equal "${{ steps.meta.outputs.tags }}", build.fetch("tags")
    assert_equal "${{ steps.meta.outputs.labels }}", build.fetch("labels")
    assert_equal ".", build.fetch("context")
    refute_includes metadata.to_s, "github.sha"
  end

  def test_only_push_events_promote_channels_or_semver
    assert_equal "latest=false", metadata.fetch("flavor")
    tags = metadata.fetch("tags").lines.map(&:strip)
    assert_equal 4, tags.size
    assert_includes tags, "type=raw,value=latest,enable=${{ #{PUSH_MAIN} }}"
    assert_includes tags, "type=raw,value=stable,enable=${{ #{PUSH_TAG} }}"
    assert_includes tags, "type=semver,pattern={{version}},value=${{ github.ref_name }},enable=${{ #{PUSH_TAG} }}"

    # Evaluate only the two asserted predicates, not the general Actions language.
    cases = [
      [ "push", "refs/heads/main", nil, true, false ],
      [ "push", "refs/tags/v1.2.3", nil, false, true ],
      [ "push", "refs/heads/feature", nil, false, false ],
      [ "push", "refs/tags/other", nil, false, false ],
      # Input is deliberately absent from both asserted promotion predicates.
      [ "workflow_dispatch", "refs/heads/main", "feature", false, false ],
      [ "workflow_dispatch", "refs/heads/main", "a" * 40, false, false ],
      [ "workflow_dispatch", "refs/heads/main", "refs/tags/v1.2.3", false, false ],
      [ "workflow_dispatch", "refs/heads/main", "main", false, false ],
      [ "workflow_dispatch", "refs/heads/feature", "main", false, false ],
      [ "workflow_dispatch", "refs/tags/v1.2.3", "feature", false, false ]
    ]
    cases.each do |event, ref, input, latest, stable|
      context = "#{event}: #{ref}, input=#{input.inspect}"
      assert_equal latest, promotion_enabled?(PUSH_MAIN, event, ref), "#{context} latest"
      assert_equal stable, promotion_enabled?(PUSH_TAG, event, ref), "#{context} stable/semver"
    end
  end

  def promotion_enabled?(predicate, event, ref)
    predicate.split(" && ").all? do |term|
      case term
      when "github.event_name == 'push'" then event == "push"
      when "github.ref == 'refs/heads/main'" then ref == "refs/heads/main"
      when "startsWith(github.ref, 'refs/tags/v')" then ref.start_with?("refs/tags/v")
      else raise "Unsupported predicate: #{term}"
      end
    end
  end
end
