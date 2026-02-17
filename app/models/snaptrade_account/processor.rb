class SnapTradeAccount::Processor
  include SnapTradeAccount::TypeMappable

  attr_reader :snaptrade_account

  def initialize(snaptrade_account)
    @snaptrade_account = snaptrade_account
  end

  def process
    process_account!
    process_positions
    process_activities
  end

  private
    def family
      snaptrade_account.snaptrade_connection.family
    end

    def security_resolver
      @security_resolver ||= SnapTradeAccount::SecurityResolver.new(snaptrade_account)
    end

    def process_account!
      SnapTradeAccount.transaction do
        account = family.accounts.find_or_initialize_by(
          snaptrade_account_id: snaptrade_account.id
        )

        account.enrich_attributes(
          {
            name: snaptrade_account.display_name,
            subtype: map_subtype(snaptrade_account.snaptrade_type)
          },
          source: "snaptrade"
        )

        balance = snaptrade_account.current_balance || 0

        account.assign_attributes(
          accountable: map_accountable(snaptrade_account.snaptrade_type || "INDIVIDUAL"),
          balance: balance,
          currency: snaptrade_account.currency,
          cash_balance: compute_cash_balance(balance)
        )

        account.save!

        # Use CurrentBalanceManager directly to avoid sync_later side-effect from Account#set_current_balance,
        # since the parent SnapTradeConnection sync will schedule account syncs via schedule_account_syncs.
        Account::CurrentBalanceManager.new(account).set_current_balance(balance)
      end
    end

    def compute_cash_balance(total_balance)
      holdings_value = compute_holdings_value
      [ total_balance - holdings_value, 0 ].max
    end

    def compute_holdings_value
      positions = snaptrade_account.raw_positions_payload
      return 0 if positions.blank?
      Array(positions).sum do |p|
        qty = (p.dig("units") || p.dig("quantity") || 0).to_d
        price = (p.dig("price") || 0).to_d
        qty * price
      end
    end

    def process_positions
      SnapTradeAccount::PositionsProcessor.new(snaptrade_account, security_resolver: security_resolver).process
    rescue => e
      Rails.logger.error("[SnapTrade] Error processing positions for #{snaptrade_account.id}: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      report_exception(e)
      raise if Rails.env.development? || Rails.env.test?
    end

    def process_activities
      SnapTradeAccount::ActivitiesProcessor.new(snaptrade_account, security_resolver: security_resolver).process
    rescue => e
      Rails.logger.error("[SnapTrade] Error processing activities for #{snaptrade_account.id}: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      report_exception(e)
      raise if Rails.env.development? || Rails.env.test?
    end

    def report_exception(error)
      Sentry.capture_exception(error) do |scope|
        scope.set_tags(snaptrade_account_id: snaptrade_account.id)
      end
    end
end
