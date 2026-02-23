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

  test "returns array of release notes on success" do
    mock_client = mock
    mock_client.expects(:releases).with("RubenOussoren/roms-finance", per_page: 10).returns([ OpenStruct.new(@release_hash) ])
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_release_notes

    assert_kind_of Array, result
    assert_equal 1, result.length
    assert_equal "v1.0.0", result.first[:name]
    assert_equal "rubenoussoren", result.first[:username]
    assert_equal "https://avatars.githubusercontent.com/u/12345", result.first[:avatar]
    assert_equal "## What's New\n\n- Feature A\n- Feature B", result.first[:body]
    assert_equal Time.utc(2026, 1, 15, 12, 0, 0), result.first[:published_at]
  end

  test "falls back to tag_name when name is blank" do
    @release_hash[:name] = nil
    mock_client = mock
    mock_client.expects(:releases).returns([ OpenStruct.new(@release_hash) ])
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_release_notes

    assert_equal "v1.0.0", result.first[:name]
  end

  test "returns empty array on API error" do
    mock_client = mock
    mock_client.expects(:releases).raises(Octokit::NotFound.new(method: "GET", url: "/repos/test/releases", body: ""))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_release_notes

    assert_equal [], result
  end

  test "returns empty array on network error" do
    mock_client = mock
    mock_client.expects(:releases).raises(Faraday::ConnectionFailed.new("connection refused"))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_release_notes

    assert_equal [], result
  end

  test "returns empty array on rate limit error" do
    mock_client = mock
    mock_client.expects(:releases).raises(Octokit::TooManyRequests.new(method: "GET", url: "/repos/test/releases", body: ""))
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_release_notes

    assert_equal [], result
  end

  test "caches the result" do
    mock_client = mock
    mock_client.expects(:releases).once.returns([ OpenStruct.new(@release_hash) ])
    Octokit::Client.stubs(:new).returns(mock_client)

    cache_store = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(cache_store)

    result1 = @provider.fetch_release_notes
    result2 = @provider.fetch_release_notes

    assert_equal result1.first[:name], result2.first[:name]
  end

  test "handles missing author gracefully" do
    @release_hash[:author] = nil
    mock_client = mock
    mock_client.expects(:releases).returns([ OpenStruct.new(@release_hash) ])
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_release_notes

    assert_equal 1, result.length
    assert_nil result.first[:avatar]
    assert_equal "RubenOussoren", result.first[:username]
  end

  test "uses GITHUB_REPO env var when set" do
    mock_client = mock
    mock_client.expects(:releases).with("custom/repo", per_page: 10).returns([ OpenStruct.new(@release_hash) ])
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    ClimateControl.modify(GITHUB_REPO: "custom/repo") do
      result = @provider.fetch_release_notes
      assert_equal 1, result.length
    end
  end

  test "returns multiple releases" do
    second_release = @release_hash.merge(name: "v0.9.0", tag_name: "v0.9.0")
    mock_client = mock
    mock_client.expects(:releases).returns([
      OpenStruct.new(@release_hash),
      OpenStruct.new(second_release)
    ])
    Octokit::Client.stubs(:new).returns(mock_client)
    Rails.cache.clear

    result = @provider.fetch_release_notes

    assert_equal 2, result.length
    assert_equal "v1.0.0", result.first[:name]
    assert_equal "v0.9.0", result.second[:name]
  end
end
