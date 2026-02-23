require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "dashboard" do
    get root_path
    assert_response :ok
  end

  test "dashboard with scope=personal" do
    get root_path(scope: :personal)
    assert_response :ok
  end

  test "dashboard with scope=household" do
    get root_path(scope: :household)
    assert_response :ok
  end

  test "dashboard ignores invalid scope param" do
    get root_path(scope: :invalid)
    assert_response :ok
  end

  test "cashflow form preserves scope param" do
    get root_path(scope: :personal)
    assert_response :ok
    assert_select "turbo-frame#cashflow_sankey_section" do
      assert_select "input[type=hidden][name=scope][value=personal]"
    end
  end

  test "changelog with empty release notes" do
    github_provider = mock
    github_provider.expects(:fetch_release_notes).returns([])
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Release notes unavailable"
  end

  test "changelog with valid release notes" do
    github_provider = mock
    github_provider.expects(:fetch_release_notes).returns([
      {
        avatar: "https://avatars.githubusercontent.com/u/12345",
        username: "rubenoussoren",
        name: "v1.0.0",
        published_at: Date.new(2026, 1, 15),
        body: "## What's New\n\n- Feature A\n- Feature B"
      }
    ])
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "v1.0.0"
    assert_select "span.text-subdued", text: "by rubenoussoren"
  end

  test "changelog with incomplete release notes" do
    github_provider = mock
    github_provider.expects(:fetch_release_notes).returns([
      {
        avatar: nil,
        username: "roms-finance",
        name: "Test Release",
        published_at: nil,
        body: nil
      }
    ])
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Test Release"
  end

  test "changelog with multiple releases renders latest expanded and older collapsed" do
    github_provider = mock
    github_provider.expects(:fetch_release_notes).returns([
      {
        avatar: "https://avatars.githubusercontent.com/u/12345",
        username: "rubenoussoren",
        name: "v2.0.0",
        published_at: Date.new(2026, 2, 1),
        body: "## v2 Notes\n\n- Major update"
      },
      {
        avatar: "https://avatars.githubusercontent.com/u/12345",
        username: "rubenoussoren",
        name: "v1.1.0",
        published_at: Date.new(2026, 1, 20),
        body: "## v1.1 Notes\n\n- Minor update"
      },
      {
        avatar: nil,
        username: "rubenoussoren",
        name: "v1.0.0",
        published_at: Date.new(2026, 1, 1),
        body: "## Initial Release"
      }
    ])
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok

    # Latest release rendered as h2 (expanded card)
    assert_select "h2", text: "v2.0.0"

    # Older releases rendered inside <details> elements
    assert_select "details", 2
    assert_select "details summary span.text-primary", text: "v1.1.0"
    assert_select "details summary span.text-primary", text: "v1.0.0"
  end
end
