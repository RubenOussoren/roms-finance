class Provider::Github
  # Release notes are not fetched from an external source.
  # Returns nil; the changelog page handles this gracefully.
  def fetch_latest_release_notes
    nil
  end
end
