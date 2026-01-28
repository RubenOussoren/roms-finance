# Family-level net worth projection calculator
# Aggregates projections across all accounts for net worth trajectory
class FamilyProjectionCalculator
  attr_reader :family

  def initialize(family)
    @family = family
  end

  # Generate family-wide net worth projection
  def project(years:)
    months = years * 12
    historical = historical_net_worth_data
    projections = project_net_worth(months: months)

    {
      historical: historical,
      projections: projections,
      currency: family.currency,
      today: Date.current.iso8601,
      summary: build_summary(projections)
    }
  end

  # Quick summary metrics for the overview
  def summary_metrics
    balance_sheet = family.balance_sheet
    {
      current_net_worth: balance_sheet.net_worth,
      total_assets: balance_sheet.assets.total,
      total_liabilities: balance_sheet.liabilities.total,
      currency: family.currency
    }
  end

  private

    def historical_net_worth_data
      # Get last 12 months of net worth data
      series = family.balance_sheet.net_worth_series(period: Period.last_365_days)
      return [] if series.blank? || series.values.blank?

      series.values.map do |point|
        {
          date: point.date.iso8601,
          value: point.value.amount.to_f
        }
      end
    end

    def project_net_worth(months:)
      # Aggregate projections from all accounts
      # Eager load accountable and entries to prevent N+1 queries when calculating loan payments
      asset_accounts = family.accounts.where(classification: "asset").active.includes(:accountable, :entries)
      liability_accounts = family.accounts.where(classification: "liability").active.includes(:accountable, :entries)

      # Build monthly projections
      (1..months).map do |month|
        date = Date.current + month.months

        # Calculate projected assets
        projected_assets = asset_accounts.sum do |account|
          project_account_balance(account, month)
        end

        # Calculate projected liabilities (decreasing over time for loans)
        projected_liabilities = liability_accounts.sum do |account|
          project_account_balance(account, month)
        end

        # Net worth = assets - liabilities
        net_worth = projected_assets - projected_liabilities

        {
          date: date.iso8601,
          p10: (net_worth * 0.85).to_f.round(2),
          p25: (net_worth * 0.92).to_f.round(2),
          p50: net_worth.to_f.round(2),
          p75: (net_worth * 1.08).to_f.round(2),
          p90: (net_worth * 1.15).to_f.round(2),
          assets: projected_assets.to_f.round(2),
          liabilities: projected_liabilities.to_f.round(2)
        }
      end
    end

    def project_account_balance(account, month)
      case account.accountable_type
      when "Investment", "Crypto"
        project_investment_balance(account, month)
      when "Loan"
        project_loan_balance(account, month)
      when "Depository"
        # Savings accounts grow slowly
        account.balance * (1 + 0.02 / 12) ** month
      else
        # Other accounts stay relatively flat
        account.balance
      end
    end

    def project_investment_balance(account, month)
      rate = cached_assumption&.effective_return || 0.06
      contribution = cached_assumption&.monthly_contribution || 0

      calculator = ProjectionCalculator.new(
        principal: account.balance,
        rate: rate,
        contribution: contribution,
        currency: account.currency
      )
      calculator.future_value_at_month(month)
    end

    # Memoize projection_assumptions to avoid N+1 queries (120×N queries per page)
    def cached_assumption
      @cached_assumption ||= family.projection_assumptions.active.first
    end

    def project_loan_balance(account, month)
      loan = account.accountable
      return account.balance if loan.nil?

      # Use amortization to project remaining balance
      return 0 if account.balance <= 0

      interest_rate = loan.interest_rate || 5.0
      monthly_rate = interest_rate / 100.0 / 12
      payment = loan.monthly_payment&.amount || 0

      return account.balance if payment <= 0

      # Calculate remaining balance using amortization formula
      balance = account.balance.abs
      month.times do
        break if balance <= 0
        interest = balance * monthly_rate
        principal_payment = [ payment - interest, balance ].min
        balance -= principal_payment
      end

      [ balance, 0 ].max
    end

    def build_summary(projections)
      return {} if projections.empty?

      final = projections.last
      {
        projected_net_worth: final[:p50],
        projected_assets: final[:assets],
        projected_liabilities: final[:liabilities],
        projection_date: final[:date]
      }
    end
end
