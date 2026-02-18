require "test_helper"

class Provider::AlphaVantageTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest, SecurityProviderInterfaceTest

  setup do
    @subject = @alpha_vantage = Provider::AlphaVantage.new(ENV["ALPHA_VANTAGE_API_KEY"] || "test_alpha_vantage_key")
  end

  test "health check" do
    VCR.use_cassette("alpha_vantage/health") do
      assert @alpha_vantage.healthy?
    end
  end

  test "usage info" do
    usage = @alpha_vantage.usage.data
    assert_equal 25, usage.limit
    assert_equal "free", usage.plan
  end

  test "applies TSX suffix for Toronto exchange" do
    assert_equal "VCN.TRT", @alpha_vantage.send(:apply_suffix, "VCN", "XTSE")
  end

  test "applies TSX Venture suffix" do
    assert_equal "VGRO.TRV", @alpha_vantage.send(:apply_suffix, "VGRO", "XTSX")
  end

  test "no suffix for US exchanges" do
    assert_equal "AAPL", @alpha_vantage.send(:apply_suffix, "AAPL", "XNAS")
    assert_equal "MSFT", @alpha_vantage.send(:apply_suffix, "MSFT", "XNYS")
  end

  test "strips suffix from Alpha Vantage symbols" do
    assert_equal "VCN", @alpha_vantage.send(:strip_suffix, "VCN.TRT")
    assert_equal "VGRO", @alpha_vantage.send(:strip_suffix, "VGRO.TRV")
    assert_equal "AAPL", @alpha_vantage.send(:strip_suffix, "AAPL")
  end

  test "detects currency from exchange MIC" do
    assert_equal "CAD", @alpha_vantage.send(:detect_currency, "XTSE")
    assert_equal "CAD", @alpha_vantage.send(:detect_currency, "XTSX")
    assert_equal "USD", @alpha_vantage.send(:detect_currency, "XNAS")
    assert_equal "GBP", @alpha_vantage.send(:detect_currency, "XLON")
  end
end
