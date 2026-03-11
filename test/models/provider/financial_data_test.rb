require "test_helper"

class Provider::FinancialDataTest < ActiveSupport::TestCase
  include SecurityProviderInterfaceTest

  CACHED_SYMBOLS = [
    { symbol: "AAPL", name: "Apple Inc.", country_code: "US", exchange_mic: "XNAS", raw_symbol: "AAPL" },
    { symbol: "MSFT", name: "Microsoft Corporation", country_code: "US", exchange_mic: "XNAS", raw_symbol: "MSFT" },
    { symbol: "VCN", name: "Vanguard FTSE Canada All Cap Index ETF", country_code: "CA", exchange_mic: "XTSE", raw_symbol: "VCN.TO" },
    { symbol: "GOOGL", name: "Alphabet Inc.", country_code: "US", exchange_mic: "XNAS", raw_symbol: "GOOGL" }
  ].freeze

  setup do
    @subject = @financial_data = Provider::FinancialData.new("test_financial_data_key")

    # Test environment uses NullStore, so stub Rails.cache with a memory store for symbol cache tests
    @test_cache = ActiveSupport::Cache::MemoryStore.new
    @test_cache.write(Provider::FinancialData::SYMBOL_CACHE_KEY, CACHED_SYMBOLS, expires_in: 1.hour)
    Rails.stubs(:cache).returns(@test_cache)
  end

  test "health check" do
    VCR.use_cassette("financial_data/health") do
      assert @financial_data.healthy?
    end
  end

  test "usage info" do
    usage = @financial_data.usage.data
    assert_equal 300, usage.limit
    assert_equal "free", usage.plan
  end

  test "applies TSX suffix for Toronto exchange" do
    assert_equal "VCN.TO", @financial_data.send(:apply_suffix, "VCN", "XTSE")
  end

  test "applies TSX Venture suffix" do
    assert_equal "VGRO.V", @financial_data.send(:apply_suffix, "VGRO", "XTSX")
  end

  test "applies London suffix" do
    assert_equal "HSBA.L", @financial_data.send(:apply_suffix, "HSBA", "XLON")
  end

  test "no suffix for US exchanges" do
    assert_equal "AAPL", @financial_data.send(:apply_suffix, "AAPL", "XNAS")
    assert_equal "MSFT", @financial_data.send(:apply_suffix, "MSFT", "XNYS")
  end

  test "strips suffix from financialdata.net symbols" do
    assert_equal "VCN", @financial_data.send(:strip_suffix, "VCN.TO")
    assert_equal "VGRO", @financial_data.send(:strip_suffix, "VGRO.V")
    assert_equal "HSBA", @financial_data.send(:strip_suffix, "HSBA.L")
    assert_equal "AAPL", @financial_data.send(:strip_suffix, "AAPL")
  end

  test "resolves MIC from suffix" do
    assert_equal "XTSE", @financial_data.send(:resolve_mic_from_suffix, "VCN.TO")
    assert_equal "XTSX", @financial_data.send(:resolve_mic_from_suffix, "VGRO.V")
    assert_equal "XLON", @financial_data.send(:resolve_mic_from_suffix, "HSBA.L")
    assert_equal "XNAS", @financial_data.send(:resolve_mic_from_suffix, "AAPL")
  end

  test "detects currency from exchange MIC" do
    assert_equal "CAD", @financial_data.send(:detect_currency, "XTSE")
    assert_equal "CAD", @financial_data.send(:detect_currency, "XTSX")
    assert_equal "USD", @financial_data.send(:detect_currency, "XNAS")
    assert_equal "GBP", @financial_data.send(:detect_currency, "XLON")
  end

  test "search_securities with warm cache returns exact matches first" do
    response = @financial_data.search_securities("AAPL", country_code: "US")
    securities = response.data

    assert securities.any?
    assert_equal "AAPL", securities.first.symbol
    assert_equal "Apple Inc.", securities.first.name
  end

  test "search_securities with warm cache filters by country_code" do
    response = @financial_data.search_securities("V", country_code: "CA")
    securities = response.data

    assert securities.any?
    assert securities.all? { |s| s.country_code == "CA" }
  end

  test "search_securities with warm cache filters by exchange_operating_mic" do
    response = @financial_data.search_securities("VCN", exchange_operating_mic: "XTSE")
    securities = response.data

    assert securities.any?
    assert_equal "VCN", securities.first.symbol
    assert_equal "XTSE", securities.first.exchange_operating_mic
  end

  test "search_securities with cold cache falls back to database" do
    @test_cache.delete(Provider::FinancialData::SYMBOL_CACHE_KEY)

    response = @financial_data.search_securities("AAPL", country_code: "US")
    securities = response.data

    assert securities.any?
    assert_equal "AAPL", securities.first.symbol
  end

  test "search_securities with warm cache matches by name substring" do
    response = @financial_data.search_securities("Apple")
    securities = response.data

    assert securities.any?
    assert_equal "AAPL", securities.first.symbol
  end

  test "uses international endpoint for TSX securities" do
    assert @financial_data.send(:international_exchange?, "XTSE")
    assert @financial_data.send(:international_exchange?, "XTSX")
    assert @financial_data.send(:international_exchange?, "XLON")
    assert_not @financial_data.send(:international_exchange?, "XNAS")
    assert_not @financial_data.send(:international_exchange?, "XNYS")
  end
end
