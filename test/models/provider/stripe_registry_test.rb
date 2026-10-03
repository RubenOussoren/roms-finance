require "test_helper"

class Provider::StripeRegistryTest < ActiveSupport::TestCase
  test "configured Stripe provider receives both secrets" do
    with_env_overrides STRIPE_SECRET_KEY: "sk_test_regression", STRIPE_WEBHOOK_SECRET: "whsec_regression" do
      provider = mock
      Provider::Stripe.expects(:new).with(secret_key: "sk_test_regression", webhook_secret: "whsec_regression").returns(provider)

      assert_same provider, Provider::Registry.get_provider(:stripe)
    end
  end

  test "missing empty or whitespace webhook secret disables Stripe" do
    [ nil, "", " " ].each do |secret|
      with_env_overrides STRIPE_SECRET_KEY: "sk_test_regression", STRIPE_WEBHOOK_SECRET: secret do
        Provider::Stripe.expects(:new).never
        assert_nil Provider::Registry.get_provider(:stripe)
      end
    end
  end

  test "missing empty or whitespace API key disables Stripe" do
    [ nil, "", " " ].each do |key|
      with_env_overrides STRIPE_SECRET_KEY: key, STRIPE_WEBHOOK_SECRET: "whsec_regression" do
        Provider::Stripe.expects(:new).never
        assert_nil Provider::Registry.get_provider(:stripe)
      end
    end
  end
end
