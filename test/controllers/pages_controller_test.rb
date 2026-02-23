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

  test "changelog with nil release notes" do
    # Mock the GitHub provider to return nil (simulating API failure or no releases)
    github_provider = mock
    github_provider.expects(:fetch_latest_release_notes).returns(nil)
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Release notes unavailable"
  end

  test "changelog with valid release notes" do
    github_provider = mock
    github_provider.expects(:fetch_latest_release_notes).returns({
      avatar: "https://avatars.githubusercontent.com/u/12345",
      username: "rubenoussoren",
      name: "v1.0.0",
      published_at: Date.new(2026, 1, 15),
      body: "## What's New\n\n- Feature A\n- Feature B"
    })
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "v1.0.0"
    assert_select "span.text-primary", text: "rubenoussoren"
  end

  test "changelog with incomplete release notes" do
    # Mock the GitHub provider to return incomplete data (missing some fields)
    github_provider = mock
    incomplete_data = {
      avatar: nil,
      username: "roms-finance",
      name: "Test Release",
      published_at: nil,
      body: nil
    }
    github_provider.expects(:fetch_latest_release_notes).returns(incomplete_data)
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Test Release"
    # Should not crash even with nil values
  end
end
