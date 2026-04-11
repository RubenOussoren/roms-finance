require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "alpha_vantage configured with ENV" do
    Setting.stubs(:market_data_alpha_vantage_api_key).returns(nil)

    with_env_overrides MARKET_DATA_ALPHA_VANTAGE_API_KEY: "test_key" do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "alpha_vantage configured with Setting" do
    Setting.stubs(:market_data_alpha_vantage_api_key).returns("test_key")

    with_env_overrides MARKET_DATA_ALPHA_VANTAGE_API_KEY: nil do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "alpha_vantage not configured" do
    Setting.stubs(:market_data_alpha_vantage_api_key).returns(nil)

    with_env_overrides MARKET_DATA_ALPHA_VANTAGE_API_KEY: nil do
      assert_nil Provider::Registry.get_provider(:alpha_vantage)
    end
  end

  test "financial_data configured with ENV" do
    Setting.stubs(:market_data_financial_data_api_key).returns(nil)

    with_env_overrides MARKET_DATA_FINANCIAL_DATA_API_KEY: "test_key" do
      assert_instance_of Provider::FinancialData, Provider::Registry.get_provider(:financial_data)
    end
  end

  test "financial_data configured with Setting" do
    Setting.stubs(:market_data_financial_data_api_key).returns("test_key")

    with_env_overrides MARKET_DATA_FINANCIAL_DATA_API_KEY: nil do
      assert_instance_of Provider::FinancialData, Provider::Registry.get_provider(:financial_data)
    end
  end

  test "financial_data not configured" do
    Setting.stubs(:market_data_financial_data_api_key).returns(nil)

    with_env_overrides MARKET_DATA_FINANCIAL_DATA_API_KEY: nil do
      assert_nil Provider::Registry.get_provider(:financial_data)
    end
  end

  test "market_data_provider defaults to financial_data" do
    Setting.stubs(:market_data_financial_data_api_key).returns("test_key")
    Setting.stubs(:market_data_provider).returns("financial_data")

    with_env_overrides MARKET_DATA_FINANCIAL_DATA_API_KEY: nil, MARKET_DATA_PROVIDER: nil do
      assert_instance_of Provider::FinancialData, Provider::Registry.get_provider(:market_data_provider)
    end
  end

  test "market_data_provider returns alpha_vantage when configured via ENV" do
    Setting.stubs(:market_data_alpha_vantage_api_key).returns("test_key")

    with_env_overrides MARKET_DATA_ALPHA_VANTAGE_API_KEY: nil, MARKET_DATA_PROVIDER: "alpha_vantage" do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:market_data_provider)
    end
  end

  test "market_data_provider returns alpha_vantage when configured via Setting" do
    Setting.stubs(:market_data_alpha_vantage_api_key).returns("test_key")
    Setting.stubs(:market_data_provider).returns("alpha_vantage")

    with_env_overrides MARKET_DATA_ALPHA_VANTAGE_API_KEY: nil, MARKET_DATA_PROVIDER: nil do
      assert_instance_of Provider::AlphaVantage, Provider::Registry.get_provider(:market_data_provider)
    end
  end

  test "securities concept uses market_data_provider" do
    Setting.stubs(:market_data_financial_data_api_key).returns("test_key")
    Setting.stubs(:market_data_provider).returns("financial_data")

    with_env_overrides MARKET_DATA_FINANCIAL_DATA_API_KEY: nil, MARKET_DATA_PROVIDER: nil do
      registry = Provider::Registry.for_concept(:securities)
      providers = registry.providers
      assert_equal 1, providers.length
      assert_instance_of Provider::FinancialData, providers.first
    end
  end

  test "exchange_rates concept uses frankfurter" do
    registry = Provider::Registry.for_concept(:exchange_rates)
    providers = registry.providers
    assert_equal 1, providers.length
    assert_instance_of Provider::Frankfurter, providers.first
  end
end
