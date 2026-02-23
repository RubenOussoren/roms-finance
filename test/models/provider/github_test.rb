require "test_helper"

class Provider::GithubTest < ActiveSupport::TestCase
  setup do
    @provider = Provider::Github.new
    @release_hash = {
      name: "v1.0.0",
      tag_name: "v1.0.0",
      published_at: Time.utc(2026, 1, 15, 12, 0, 0),
      body: "## What's New\n\n- Feature A\n- Feature B",
      author: {
        login: "rubenoussoren",
        avatar_url: "https://avatars.githubusercontent.com/u/12345"
      }
    }
  end

  test "returns release notes on success" do
    mock_client = mock
    mock_client.expects(:latest_release).returns(OpenStruct.new(@release_hash))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_latest_release_notes

    assert_not_nil result
    assert_equal "v1.0.0", result[:name]
    assert_equal "rubenoussoren", result[:username]
    assert_equal "https://avatars.githubusercontent.com/u/12345", result[:avatar]
    assert_equal "## What's New\n\n- Feature A\n- Feature B", result[:body]
    assert_equal Time.utc(2026, 1, 15, 12, 0, 0), result[:published_at]
  end

  test "falls back to tag_name when name is blank" do
    @release_hash[:name] = nil
    mock_client = mock
    mock_client.expects(:latest_release).returns(OpenStruct.new(@release_hash))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_latest_release_notes

    assert_equal "v1.0.0", result[:name]
  end

  test "returns nil on API error" do
    mock_client = mock
    mock_client.expects(:latest_release).raises(Octokit::NotFound.new(method: "GET", url: "/repos/test/releases/latest", body: ""))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_latest_release_notes

    assert_nil result
  end

  test "returns nil on network error" do
    mock_client = mock
    mock_client.expects(:latest_release).raises(Faraday::ConnectionFailed.new("connection refused"))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_latest_release_notes

    assert_nil result
  end

  test "returns nil on rate limit error" do
    mock_client = mock
    mock_client.expects(:latest_release).raises(Octokit::TooManyRequests.new(method: "GET", url: "/repos/test/releases/latest", body: ""))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_latest_release_notes

    assert_nil result
  end

  test "caches the result" do
    mock_client = mock
    mock_client.expects(:latest_release).once.returns(OpenStruct.new(@release_hash))
    Octokit::Client.stubs(:new).returns(mock_client)

    cache_store = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(cache_store)

    result1 = @provider.fetch_latest_release_notes
    result2 = @provider.fetch_latest_release_notes

    assert_equal result1[:name], result2[:name]
  end

  test "handles missing author gracefully" do
    @release_hash[:author] = nil
    mock_client = mock
    mock_client.expects(:latest_release).returns(OpenStruct.new(@release_hash))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_latest_release_notes

    assert_not_nil result
    assert_nil result[:avatar]
    assert_equal "RubenOussoren", result[:username]
  end

  test "uses GITHUB_REPO env var when set" do
    mock_client = mock
    mock_client.expects(:latest_release).with("custom/repo").returns(OpenStruct.new(@release_hash))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    ClimateControl.modify(GITHUB_REPO: "custom/repo") do
      result = @provider.fetch_latest_release_notes
      assert_not_nil result
    end
  end
end
