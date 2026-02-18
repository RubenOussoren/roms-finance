require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "synth configured with ENV" do
    Setting.stubs(:synth_api_key).returns(nil)

    with_env_overrides SYNTH_API_KEY: "123" do
      assert_instance_of Provider::Synth, Provider::Registry.get_provider(:synth)
    end
  end

  test "synth configured with Setting" do
    Setting.stubs(:synth_api_key).returns("123")

    with_env_overrides SYNTH_API_KEY: nil do
      assert_instance_of Provider::Synth, Provider::Registry.get_provider(:synth)
    end
  end

  test "synth not configured" do
    Setting.stubs(:synth_api_key).returns(nil)

    with_env_overrides SYNTH_API_KEY: nil do
      assert_nil Provider::Registry.get_provider(:synth)
    end
  end

  test "alpha_vantage configured with ENV" do
    Setting.stubs(:alpha_vantage_api_key).returns(nil)

    with_env_overrides ALPHA_VANTAGE_API_KEY: "test_key" do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "alpha_vantage configured with Setting" do
    Setting.stubs(:alpha_vantage_api_key).returns("test_key")

    with_env_overrides ALPHA_VANTAGE_API_KEY: nil do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "alpha_vantage not configured" do
    Setting.stubs(:alpha_vantage_api_key).returns(nil)

    with_env_overrides ALPHA_VANTAGE_API_KEY: nil do
      assert_nil Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "market_data_provider returns synth by default" do
    Setting.stubs(:market_data_provider).returns("synth")
    Setting.stubs(:synth_api_key).returns("123")

    with_env_overrides SYNTH_API_KEY: nil do
      assert_instance_of Provider::Synth, Provider::Registry.get_provider(:market_data_provider)
    end
  end

  test "market_data_provider returns alpha_vantage when configured" do
    Setting.stubs(:market_data_provider).returns("alpha_vantage")
    Setting.stubs(:alpha_vantage_api_key).returns("test_key")

    with_env_overrides ALPHA_VANTAGE_API_KEY: nil do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:market_data_provider)
    end
  end

  test "securities concept uses market_data_provider" do
    Setting.stubs(:market_data_provider).returns("synth")
    Setting.stubs(:synth_api_key).returns("123")

    with_env_overrides SYNTH_API_KEY: nil do
      registry = Provider::Registry.for_concept(:securities)
      providers = registry.providers
      assert_equal 1, providers.length
      assert_instance_of Provider::Synth, providers.first
    end
  end

  test "exchange_rates concept uses market_data_provider" do
    Setting.stubs(:market_data_provider).returns("alpha_vantage")
    Setting.stubs(:alpha_vantage_api_key).returns("test_key")

    with_env_overrides ALPHA_VANTAGE_API_KEY: nil do
      registry = Provider::Registry.for_concept(:exchange_rates)
      providers = registry.providers
      assert_equal 1, providers.length
      assert_instance_of Provider::AlphaVantage, providers.first
    end
  end
end
