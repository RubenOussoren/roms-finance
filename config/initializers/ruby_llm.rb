Rails.application.config.after_initialize do
  RubyLLM.configure do |config|
    config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", nil) || Setting.openai_access_token
    config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil) || Setting.anthropic_api_key
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  # Database not yet created — configure with ENV only
  RubyLLM.configure do |config|
    config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", nil)
    config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  end
end
