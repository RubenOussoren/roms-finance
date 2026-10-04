require "sidekiq/web"

if Rails.env.production?
  Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
    SidekiqWebAuthentication.authenticated?(
      username, password,
      configured_username: ENV["SIDEKIQ_WEB_USERNAME"],
      configured_password: ENV["SIDEKIQ_WEB_PASSWORD"]
    )
  end
end

Sidekiq::Cron.configure do |config|
  # 10 min "catch-up" window in case worker process is re-deploying when cron tick occurs
  config.reschedule_grace_period = 600
end
