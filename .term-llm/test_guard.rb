# Loaded before Rails, including schema/fixture tasks. This is a test-only harness.
abort "Autonomy requires isolated test context" unless ENV["RAILS_ENV"] == "test" && ENV["POSTGRES_DB"] == "roms_autonomy_test" && ENV["DB_HOST"] == "db" && ENV["REDIS_URL"] == "redis://roms-autonomy-test-redis:6379/0"
require "bundler/setup"
require "rails"
require "dotenv"
require "dotenv/rails"
Dotenv::Rails.files = []
# Never decrypt application credentials in the disposable harness.
module AutonomyCredentials
  def credentials
    @autonomy_credentials ||= ActiveSupport::OrderedOptions.new
  end
end
Rails::Application.prepend(AutonomyCredentials)
require "webmock"
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
require "vcr"
VCR.configure { |config| config.default_cassette_options = { record: :none } }
require "capybara/playwright"
require "uri"
module AutonomyBrowserNetwork
  private

    def create_browser_context
      super.tap do |context|
        context.route("**/*", ->(route, request) {
          uri = URI(request.url)
          server = Capybara.current_session.server
          if server && uri.scheme == "http" && uri.host == "127.0.0.1" && uri.port == server.port
            route.continue
          else
            route.abort
          end
        })
      end
    end
end
Capybara::Playwright::Browser.prepend(AutonomyBrowserNetwork)
