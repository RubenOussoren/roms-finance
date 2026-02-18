require "test_helper"

module ExchangeRateProviderInterfaceTest
  extend ActiveSupport::Testing::Declarative

  test "fetches single exchange rate" do
    VCR.use_cassette("#{vcr_key_prefix}/exchange_rate") do
      response = @subject.fetch_exchange_rate(
        from: "USD",
        to: "GBP",
        date: Date.iso8601("2026-02-10")
      )

      rate = response.data

      assert_equal "USD", rate.from
      assert_equal "GBP", rate.to
      assert rate.date.is_a?(Date)
      assert rate.rate > 0
    end
  end

  test "fetches paginated exchange_rate historical data" do
    VCR.use_cassette("#{vcr_key_prefix}/exchange_rates") do
      response = @subject.fetch_exchange_rates(
        from: "USD", to: "GBP", start_date: Date.iso8601("2026-01-15"), end_date: Date.iso8601("2026-02-14")
      )

      assert response.data.count > 0
      assert response.data.first.date.is_a?(Date)
    end
  end

  private
    def vcr_key_prefix
      @subject.class.name.demodulize.underscore
    end
end
