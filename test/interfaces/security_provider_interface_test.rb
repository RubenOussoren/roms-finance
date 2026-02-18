require "test_helper"

module SecurityProviderInterfaceTest
  extend ActiveSupport::Testing::Declarative

  test "fetches security price" do
    aapl = securities(:aapl)

    VCR.use_cassette("#{vcr_key_prefix}/security_price") do
      response = @subject.fetch_security_price(symbol: aapl.ticker, exchange_operating_mic: aapl.exchange_operating_mic, date: Date.iso8601("2026-02-10"))

      assert response.success?
      assert response.data.present?
    end
  end

  test "fetches paginated securities prices" do
    aapl = securities(:aapl)

    VCR.use_cassette("#{vcr_key_prefix}/security_prices") do
      response = @subject.fetch_security_prices(
        symbol: aapl.ticker,
        exchange_operating_mic: aapl.exchange_operating_mic,
        start_date: Date.iso8601("2026-01-15"),
        end_date: Date.iso8601("2026-02-14")
      )

      assert response.success?
      assert response.data.count > 0
      assert response.data.first.date.is_a?(Date)
    end
  end

  test "searches securities" do
    VCR.use_cassette("#{vcr_key_prefix}/security_search") do
      response = @subject.search_securities("AAPL", country_code: "US")
      securities = response.data

      assert securities.any?
      security = securities.first
      assert_equal "AAPL", security.symbol
    end
  end

  test "fetches security info" do
    aapl = securities(:aapl)

    VCR.use_cassette("#{vcr_key_prefix}/security_info") do
      response = @subject.fetch_security_info(
        symbol: aapl.ticker,
        exchange_operating_mic: aapl.exchange_operating_mic
      )

      info = response.data

      assert_equal "AAPL", info.symbol
    end
  end

  private
    def vcr_key_prefix
      @subject.class.name.demodulize.underscore
    end
end
