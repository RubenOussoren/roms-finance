# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :alpha_vantage_api_key, type: :string, default: ENV["ALPHA_VANTAGE_API_KEY"]
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]

  # Defaults to invite-only when INVITE_ONLY env var is unset (secure-by-default for self-hosted).
  # Only applies in self-hosted mode; managed mode uses ENV["REQUIRE_INVITE_CODE"] directly.
  field :require_invite_for_signup, type: :boolean, default: ENV.fetch("INVITE_ONLY", "true") == "true"
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end
