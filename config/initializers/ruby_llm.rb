# Set before after_initialize so the railtie picks it up
# (railtie checks this on ActiveRecord load, before after_initialize runs)
RubyLLM.config.use_new_acts_as = true

Rails.application.config.after_initialize do
  RubyLLM.configure do |config|
    config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", nil) || Setting.openai_access_token
    config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil) || Setting.anthropic_api_key
    config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil) || Setting.gemini_api_key
    config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", nil) || Setting.ollama_api_base
  end

  # Only fetch models when at least one provider is configured.
  # In CI/test with no keys, this would hang on the models.dev API call.
  if RubyLLM.config.openai_api_key.present? ||
     RubyLLM.config.anthropic_api_key.present? ||
     RubyLLM.config.gemini_api_key.present? ||
     RubyLLM.config.ollama_api_base.present?
    RubyLLM.models.refresh!
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  # Database not yet created — configure with ENV only
  RubyLLM.configure do |config|
    config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", nil)
    config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
    config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)
    config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", nil)
  end
end
