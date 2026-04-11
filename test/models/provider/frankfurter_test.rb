require "test_helper"

class Provider::FrankfurterTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest

  setup do
    @subject = @frankfurter = Provider::Frankfurter.new
  end

  test "health check" do
    VCR.use_cassette("frankfurter/health") do
      assert @frankfurter.healthy?
    end
  end

  test "fetches single exchange rate for any currency pair" do
    VCR.use_cassette("frankfurter/exchange_rate") do
      response = @frankfurter.fetch_exchange_rate(from: "USD", to: "GBP", date: Date.iso8601("2026-02-10"))

      assert response.success?
      rate = response.data
      assert_equal "USD", rate.from
      assert_equal "GBP", rate.to
      assert_equal Date.iso8601("2026-02-10"), rate.date
      assert_in_delta 0.7982, rate.rate, 0.01
    end
  end

  test "fetches exchange rate series for date range" do
    VCR.use_cassette("frankfurter/exchange_rates") do
      response = @frankfurter.fetch_exchange_rates(
        from: "USD", to: "GBP",
        start_date: Date.iso8601("2026-01-15"),
        end_date: Date.iso8601("2026-02-14")
      )

      assert response.success?
      rates = response.data
      assert rates.size > 10
      assert rates.all? { |r| r.from == "USD" && r.to == "GBP" }
      assert rates.all? { |r| r.rate > 0 }
      assert_equal rates.sort_by(&:date), rates
    end
  end

  test "returns the requested date even for weekends" do
    VCR.use_cassette("frankfurter/exchange_rate") do
      # Frankfurter returns previous business day data but we return the requested date
      response = @frankfurter.fetch_exchange_rate(from: "USD", to: "GBP", date: Date.iso8601("2026-02-10"))
      assert_equal Date.iso8601("2026-02-10"), response.data.date
    end
  end

  test "no api key required" do
    provider = Provider::Frankfurter.new
    assert provider.is_a?(Provider::Frankfurter)
  end

  test "returns error for unsupported currency" do
    VCR.use_cassette("frankfurter/unsupported_currency") do
      response = @frankfurter.fetch_exchange_rate(from: "USD", to: "XYZ", date: Date.iso8601("2026-03-06"))

      assert_not response.success?
      assert response.error.is_a?(Provider::Frankfurter::Error)
    end
  end
end
