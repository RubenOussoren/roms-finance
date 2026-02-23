class Provider::Github < Provider
  def fetch_release_notes
    response = with_provider_response do
      releases = Rails.cache.fetch("github_releases", expires_in: 6.hours) do
        client.releases(repo, per_page: 10).map(&:to_h)
      end

      raise Error, "No releases found" if releases.blank?

      releases.map do |release|
        author = release[:author] || {}

        {
          avatar: author[:avatar_url],
          username: author[:login] || repo.split("/").first,
          name: release[:name].presence || release[:tag_name],
          published_at: release[:published_at],
          body: release[:body]
        }
      end
    end

    response.success? ? response.data : []
  end

  private

    def client
      Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"])
    end

    def repo
      ENV.fetch("GITHUB_REPO", "RubenOussoren/roms-finance")
    end
end
