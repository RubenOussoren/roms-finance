# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :market_data_alpha_vantage_api_key, type: :string, default: ENV["MARKET_DATA_ALPHA_VANTAGE_API_KEY"]
  field :market_data_financial_data_api_key, type: :string, default: ENV["MARKET_DATA_FINANCIAL_DATA_API_KEY"]
  field :market_data_provider, type: :string, default: ENV.fetch("MARKET_DATA_PROVIDER", "financial_data")
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
  field :anthropic_api_key, type: :string, default: ENV["ANTHROPIC_API_KEY"]
  field :gemini_api_key, type: :string, default: ENV["GEMINI_API_KEY"]
  field :ollama_api_base, type: :string, default: ENV.fetch("OLLAMA_API_BASE", nil)
  field :default_ai_model, type: :string, default: ENV.fetch("DEFAULT_AI_MODEL", "gpt-5-mini")

  # Defaults to invite-only when INVITE_ONLY env var is unset (secure-by-default for self-hosted).
  # Only applies in self-hosted mode; managed mode uses ENV["REQUIRE_INVITE_CODE"] directly.
  field :require_invite_for_signup, type: :boolean, default: ENV.fetch("INVITE_ONLY", "true") == "true"
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end
