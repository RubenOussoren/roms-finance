require_relative "../config/environment"
require "net/http"
raise "dotenv files enabled" unless Dotenv::Rails.files.empty?
raise "credentials available" unless Rails.application.credentials.empty?
configs = ActiveRecord::Base.configurations.configs_for(env_name: "test")
raise "Unexpected DB config" unless configs.size == 1 && configs.all? { |c| c.database == "roms_autonomy_test" && c.configuration_hash[:host] == "db" }
raise "Wrong connected DB" unless ActiveRecord::Base.connection.select_value("SELECT current_database()") == "roms_autonomy_test"
raise "Wrong Redis" unless Redis.new(url: ENV.fetch("REDIS_URL")).ping == "PONG"
raise "Live job adapter" unless Rails.application.config.active_job.queue_adapter == :test
raise "Live mail" unless ActionMailer::Base.delivery_method == :test
begin
  Net::HTTP.get(URI("https://example.invalid/autonomy-must-block"))
  raise "External HTTP allowed"
rescue WebMock::NetConnectNotAllowedError
  puts "Verified: isolated DB/Redis; empty dotenv/credentials; test jobs/mail; external HTTP blocked"
end
