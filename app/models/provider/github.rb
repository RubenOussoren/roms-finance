class Provider::Github < Provider
  def fetch_latest_release_notes
    response = with_provider_response do
      release = Rails.cache.fetch("github_latest_release", expires_in: 6.hours) do
        client.latest_release(repo)&.to_h
      end

      raise Error, "No releases found" if release.nil?

      author = release[:author] || {}

      {
        avatar: author[:avatar_url],
        username: author[:login] || repo.split("/").first,
        name: release[:name].presence || release[:tag_name],
        published_at: release[:published_at],
        body: release[:body]
      }
    end

    response.success? ? response.data : nil
  end

  private

    def client
      Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"])
    end

    def repo
      ENV.fetch("GITHUB_REPO", "RubenOussoren/roms-finance")
    end
end
