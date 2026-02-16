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
            name: snaptrade_account.name,
            subtype: map_subtype(snaptrade_account.snaptrade_type)
          },
          source: "snaptrade"
        )

        balance = snaptrade_account.current_balance || 0

        account.assign_attributes(
          accountable: map_accountable(snaptrade_account.snaptrade_type || "INDIVIDUAL"),
          balance: balance,
          currency: snaptrade_account.currency,
          cash_balance: balance
        )

        account.save!

        account.set_current_balance(balance)
      end
    end

    def process_positions
      SnapTradeAccount::PositionsProcessor.new(snaptrade_account, security_resolver: security_resolver).process
    rescue => e
      report_exception(e)
    end

    def process_activities
      SnapTradeAccount::ActivitiesProcessor.new(snaptrade_account, security_resolver: security_resolver).process
    rescue => e
      report_exception(e)
    end

    def report_exception(error)
      Sentry.capture_exception(error) do |scope|
        scope.set_tags(snaptrade_account_id: snaptrade_account.id)
      end
    end
end
