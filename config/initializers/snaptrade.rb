Rails.application.configure do
  config.snaptrade = nil

  if ENV["SNAPTRADE_CLIENT_ID"].present? && ENV["SNAPTRADE_CONSUMER_KEY"].present?
    config.snaptrade = {
      client_id: ENV["SNAPTRADE_CLIENT_ID"],
      consumer_key: ENV["SNAPTRADE_CONSUMER_KEY"]
    }
  end
end
