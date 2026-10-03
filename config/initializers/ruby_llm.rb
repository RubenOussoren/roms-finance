Rails.application.config.after_initialize do
  RubyLLM.configure do |config|
    # Keep the existing wire protocol; 2.0 otherwise defaults to Responses.
    config.openai_protocol = :chat_completions
    config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", nil) || Setting.openai_access_token
    config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil) || Setting.anthropic_api_key
    config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil) || Setting.gemini_api_key
    config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", nil) || Setting.ollama_api_base
    # Setting loads ActiveRecord, whose railtie selects the database registry.
    # Our app owns persistence and needs the plain Ruby registry, not gem tables.
    config.model_registry_store = nil
  end

  # Only fetch models when at least one provider is configured.
  # In CI/test with no keys, this would hang on the models.dev API call.
  if RubyLLM.config.openai_api_key.present? ||
     RubyLLM.config.anthropic_api_key.present? ||
     RubyLLM.config.gemini_api_key.present? ||
     RubyLLM.config.ollama_api_base.present?
    RubyLLM.models.refresh
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  # Database not yet created — configure with ENV only
  RubyLLM.configure do |config|
    config.openai_protocol = :chat_completions
    config.model_registry_store = nil
    config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", nil)
    config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
    config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)
    config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", nil)
  end
end
