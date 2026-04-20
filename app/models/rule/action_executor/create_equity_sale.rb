class Rule::ActionExecutor::CreateEquitySale < Rule::ActionExecutor
  def type
    "select"
  end

  def label
    "Create equity sale"
  end

  def preposition
    "from"
  end

  def options
    family.accounts.alphabetically
      .where(accountable_type: "EquityCompensation")
      .map { |a| [ a.name, a.id ] }
  end

  def execute(transaction_scope, value: nil, ignore_attribute_locks: false)
    source_account = family.accounts.find_by_id(value)
    return if source_account.nil?
    return unless source_account.accountable_type == "EquityCompensation"

    any_sale_created = false
    bank_accounts_to_sync = Set.new

    transaction_scope.find_each do |txn|
      next if txn.transfer.present?
      next if txn.entry.account_id == source_account.id

      grant = pick_grant(source_account, txn.entry.date)
      next if grant.nil?

      entry = txn.entry
      outflow_amount = Money.new(entry.amount.abs, entry.currency)
                            .exchange_to(source_account.currency, date: entry.date, fallback_rate: 1.0)

      units = derive_units(grant, outflow_amount.amount, source_account.currency, entry.date)
      next if units.nil? || units <= 0

      ActiveRecord::Base.transaction do
        entry.update!(amount: -entry.amount.abs) if entry.amount.positive?
        txn.update!(kind: "funds_movement")

        outflow_txn = Transaction.new(
          kind: Transfer.kind_for_account(entry.account),
          entry: source_account.entries.build(
            amount: outflow_amount.amount.abs,
            currency: source_account.currency,
            date: entry.date,
            name: "Sale from #{entry.account.name}"
          )
        )

        Transfer.create!(
          inflow_transaction: txn,
          outflow_transaction: outflow_txn,
          status: "confirmed"
        )

        EquityGrantSale.create!(
          equity_grant: grant,
          entry: outflow_txn.entry,
          date: entry.date,
          units: units,
          proceeds: outflow_amount.amount.abs,
          currency: source_account.currency
        )
      end

      any_sale_created = true
      bank_accounts_to_sync << entry.account
    end

    # Regenerate once after all matched transactions are processed. Running this
    # inside the loop would re-materialize 700+ balance rows per match.
    source_account.accountable.regenerate_vesting_valuations! if any_sale_created
    bank_accounts_to_sync.each(&:sync_later)
  end

  private

    def pick_grant(source_account, as_of)
      source_account.accountable.equity_grants
        .includes(:security)
        .order(:grant_date)
        .find { |g| g.vested_units_remaining(as_of: as_of) > 0 } ||
        source_account.accountable.equity_grants.order(:grant_date).first
    end

    # Derives units given proceeds already expressed in `target_currency`. The security price
    # is FX-converted into the same currency before division so the unit count is correct
    # across mixed-currency accounts.
    def derive_units(grant, proceeds_in_target, target_currency, date)
      proceeds = proceeds_in_target.to_d
      price_record = grant.security.find_or_fetch_price(date: date, cache: false)
      price_amount = price_record&.price&.to_d
      price_currency = price_record&.currency
      if price_amount.nil?
        cp = grant.security.current_price
        price_amount = cp&.amount&.to_d
        price_currency = cp&.currency
      end
      return nil if price_amount.nil? || price_amount <= 0

      unit_price = if price_currency && price_currency != target_currency
        Money.new(price_amount, price_currency).exchange_to(target_currency, date: date, fallback_rate: 1.0).amount.to_d
      else
        price_amount
      end
      return nil if unit_price <= 0

      if grant.stock_option?
        strike = (grant.strike_price || 0).to_d
        strike = if price_currency && price_currency != target_currency
          Money.new(strike, price_currency).exchange_to(target_currency, date: date, fallback_rate: 1.0).amount.to_d
        else
          strike
        end
        spread = [ unit_price - strike, 0 ].max
        return nil if spread <= 0
        proceeds / spread
      else
        proceeds / unit_price
      end
    end
end
