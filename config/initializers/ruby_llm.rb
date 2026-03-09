RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", nil) || Setting.openai_access_token
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil) || Setting.anthropic_api_key
end
