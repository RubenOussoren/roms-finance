require "test_helper"
require "openssl"
require "jwt"

class Provider::PlaidWebhookTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 3, 1, 12, 0, 0)

    # Local keys and a stubbed API keep these tests independent of Plaid credentials
    # and exercise real ES256 signing, JWK import, and JWT verification.
    @plaid = Provider::Plaid.new(Plaid::Configuration.new)
    @signing_key = OpenSSL::PKey::EC.generate("prime256v1")
    @key_id = "webhook-test-key"
    @jwk = JWT::JWK.new(@signing_key, kid: @key_id, use: "sig").export
    @raw_body = '{"webhook_type":"TRANSACTIONS","webhook_code":"SYNC_UPDATES_AVAILABLE"}'
    @claims = {
      "iat" => Time.now.to_i,
      "request_body_sha256" => Digest::SHA256.hexdigest(@raw_body)
    }
  end

  teardown do
    travel_back
  end

  test "validates an ES256 webhook using the public JWK fetched by kid" do
    expect_verification_key

    assert_not @jwk.key?(:d), "The API stub must only expose the public key"
    assert_nothing_raised { @plaid.validate_webhook!(signed_token, @raw_body) }
  end

  test "rejects a signature from a different EC key" do
    expect_verification_key
    other_key = OpenSSL::PKey::EC.generate("prime256v1")

    assert_raises JWT::VerificationError do
      @plaid.validate_webhook!(signed_token(key: other_key), @raw_body)
    end
  end

  test "rejects HS256 before fetching a verification key" do
    @plaid.client.expects(:webhook_verification_key_get).never
    token = JWT.encode(@claims, "test-hmac-secret", "HS256", kid: @key_id)

    assert_raises JWT::IncorrectAlgorithm do
      @plaid.validate_webhook!(token, @raw_body)
    end
  end

  test "rejects an unsigned token before fetching a verification key" do
    @plaid.client.expects(:webhook_verification_key_get).never
    token = JWT.encode(@claims, nil, "none", kid: @key_id)

    assert_raises JWT::IncorrectAlgorithm do
      @plaid.validate_webhook!(token, @raw_body)
    end
  end

  test "rejects a body whose bytes differ from the signed hash" do
    expect_verification_key

    error = assert_raises JWT::VerificationError do
      @plaid.validate_webhook!(signed_token, "#{@raw_body}\n")
    end
    assert_equal "Invalid webhook body hash", error.message
  end

  test "accepts a webhook issued exactly five minutes ago" do
    expect_verification_key
    @claims["iat"] = Time.now.to_i - 5.minutes.to_i

    assert_nothing_raised { @plaid.validate_webhook!(signed_token, @raw_body) }
  end

  test "rejects a webhook issued more than five minutes ago" do
    expect_verification_key
    @claims["iat"] = Time.now.to_i - 5.minutes.to_i - 1

    error = assert_raises JWT::VerificationError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
    assert_equal "Webhook is too old", error.message
  end

  test "ignores an expired expiration claim when iat is recent" do
    expect_verification_key
    @claims["exp"] = Time.now.to_i - 1

    # Plaid validation explicitly disables expiration verification; age uses iat.
    assert_nothing_raised { @plaid.validate_webhook!(signed_token, @raw_body) }
  end

  test "missing iat raises the current Time at type error" do
    expect_verification_key
    @claims.delete("iat")

    # Characterize current behavior, not a requirement for JWT::InvalidIatError.
    assert_raises TypeError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
  end

  test "a string iat raises the current Time at type error" do
    expect_verification_key
    @claims["iat"] = "not-a-timestamp"

    assert_raises TypeError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
  end

  test "missing body hash raises the current secure compare method error" do
    expect_verification_key
    @claims.delete("request_body_sha256")

    # Application claims are not normalized to JWT errors by the provider.
    assert_raises NoMethodError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
  end

  test "a non-string body hash raises the current secure compare method error" do
    expect_verification_key
    @claims["request_body_sha256"] = 123

    assert_raises NoMethodError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
  end

  test "rejects a malformed string body hash" do
    expect_verification_key
    @claims["request_body_sha256"] = "not-a-sha256-hash"

    error = assert_raises JWT::VerificationError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
    assert_equal "Invalid webhook body hash", error.message
  end

  test "rejects a missing kid before fetching a verification key" do
    @plaid.client.expects(:webhook_verification_key_get).never

    assert_raises JWT::DecodeError do
      @plaid.validate_webhook!(signed_token(headers: {}), @raw_body)
    end
  end

  test "rejects a non-string kid before fetching a verification key" do
    @plaid.client.expects(:webhook_verification_key_get).never

    assert_raises JWT::DecodeError do
      @plaid.validate_webhook!(signed_token(headers: { kid: 123 }), @raw_body)
    end
  end

  test "filters out a JWK marked for encryption even when its signature matches" do
    expect_verification_key(@jwk.merge(use: "enc"))

    assert_raises JWT::DecodeError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
  end

  test "filters out a JWK without an explicit signing use" do
    expect_verification_key(@jwk.except(:use))

    assert_raises JWT::DecodeError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
  end

  test "rejects a signing JWK with a different kid" do
    expect_verification_key(@jwk.merge(kid: "different-key"))

    assert_raises JWT::DecodeError do
      @plaid.validate_webhook!(signed_token, @raw_body)
    end
  end

  private
    def signed_token(key: @signing_key, headers: { kid: @key_id })
      # JWT.encode validates numeric claims before signing. Use the Token API
      # (available in JWT 2.10 and 3) so malformed claims reach the provider.
      token = JWT::Token.new(payload: @claims, header: headers)
      token.sign!(algorithm: "ES256", key: key)
      token.jwt
    end

    def expect_verification_key(jwk = @jwk)
      response = stub(key: stub(to_hash: jwk))

      # JWT may reload the JWKS when no matching signing key survives filtering.
      @plaid.client.expects(:webhook_verification_key_get).with do |request|
        request.is_a?(Plaid::WebhookVerificationKeyGetRequest) && request.key_id == @key_id
      end.at_least_once.returns(response)
    end
end
