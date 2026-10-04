# Standalone: bundle exec ruby test/lib/sidekiq_web_authentication_test.rb
# Deliberately avoids test_helper, Rails boot, dotenv, and database/Redis access.
require "minitest/autorun"
require "rack/auth/basic"
require "rack/mock"
require_relative "../../lib/sidekiq_web_authentication"

class SidekiqWebAuthenticationTest < Minitest::Test
  USERNAME = "roms"
  PASSWORD = "unique-test-password-7e92"

  def test_rejects_missing_configuration
    refute authenticated?(configured_username: nil)
    refute authenticated?(configured_password: nil)
    refute authenticated?(configured_username: nil, configured_password: nil)
  end

  def test_rejects_blank_configuration_even_when_credentials_match
    [ "", " ", "\t\n", "\u00a0", "\u3000" ].each do |blank|
      refute authenticated?(username: blank, configured_username: blank)
      refute authenticated?(password: blank, configured_password: blank)
    end
  end

  def test_rejects_known_example_password_regardless_of_username
    [ USERNAME, "custom-admin" ].each do |username|
      refute authenticated?(username: username, password: "roms", configured_username: username, configured_password: "roms")
    end
  end

  def test_rejects_incorrect_credentials
    refute authenticated?(username: "wrong")
    refute authenticated?(password: "wrong")
    refute authenticated?(username: "wrong", password: "wrong")
    refute authenticated?(username: "ROMS")
    refute authenticated?(password: PASSWORD.upcase)
  end

  def test_rejects_missing_or_blank_submitted_credentials
    [ nil, "", " \t\n", "\u3000" ].each do |blank|
      refute authenticated?(username: blank)
      refute authenticated?(password: blank)
    end
  end

  def test_accepts_explicit_matching_credentials
    assert authenticated?
    assert authenticated?(username: "custom-admin", configured_username: "custom-admin")
  end

  def test_preserves_nonblank_whitespace_exactly
    username = " admin "
    password = " unique password "
    assert authenticated?(username: username, password: password, configured_username: username, configured_password: password)
    refute authenticated?(username: username.strip, password: password, configured_username: username, configured_password: password)
    refute authenticated?(username: username, password: password.strip, configured_username: username, configured_password: password)
  end

  def test_supports_unicode_with_exact_matching
    username = "管理者"
    password = "秘密-café-🔒"
    assert authenticated?(username: username, password: password, configured_username: username, configured_password: password)
    refute authenticated?(username: "別人", password: password, configured_username: username, configured_password: password)
    refute authenticated?(username: username, password: "秘密-café-🔒", configured_username: username, configured_password: password)
  end

  def test_basic_auth_denies_disabled_configuration_without_preventing_construction
    [ nil, "", "roms" ].each do |configured_password|
      app = basic_auth_app(configured_password: configured_password)
      response = Rack::MockRequest.new(app).get("/sidekiq", "HTTP_AUTHORIZATION" => basic_authorization(USERNAME, "roms"))
      assert_equal 401, response.status
    end
  end

  def test_basic_auth_challenges_unauthenticated_and_incorrect_requests_and_accepts_correct_credentials
    request = Rack::MockRequest.new(basic_auth_app)
    assert_equal 401, request.get("/sidekiq").status
    assert_equal 401, request.get("/sidekiq", "HTTP_AUTHORIZATION" => basic_authorization(USERNAME, "wrong")).status
    assert_equal 200, request.get("/sidekiq", "HTTP_AUTHORIZATION" => basic_authorization(USERNAME, PASSWORD)).status
  end

  private

    def authenticated?(username: USERNAME, password: PASSWORD, configured_username: USERNAME, configured_password: PASSWORD)
      SidekiqWebAuthentication.authenticated?(username, password, configured_username: configured_username, configured_password: configured_password)
    end

    def basic_authorization(username, password)
      "Basic #{[ "#{username}:#{password}" ].pack("m0")}"
    end

    def basic_auth_app(configured_password: PASSWORD)
      Rack::Auth::Basic.new(->(_env) { [ 200, {}, [ "dashboard" ] ] }) do |username, password|
        authenticated?(username: username, password: password, configured_password: configured_password)
      end
    end
end
