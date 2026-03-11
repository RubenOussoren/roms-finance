class FinancialDataSymbolSyncJob < ApplicationJob
  queue_as :scheduled

  def perform
    provider = Provider::Registry.get_provider(:market_data_provider)
    return unless provider.is_a?(Provider::FinancialData)

    count = provider.warm_symbol_cache!
    Rails.logger.info("FinancialDataSymbolSyncJob: cached #{count} symbols")
  end
end
