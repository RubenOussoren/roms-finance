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
      # Eager load accountable, entries, and projection_assumption to prevent N+1 queries
      asset_accounts = family.accounts.where(classification: "asset").active.includes(:accountable, :entries, :projection_assumption)
      liability_accounts = family.accounts.where(classification: "liability").active.includes(:accountable, :entries, :projection_assumption)

      # Validate currency consistency
      all_accounts = asset_accounts + liability_accounts
      mismatched = all_accounts.reject { |a| a.currency == family.currency }
      if mismatched.any?
        Rails.logger.warn "FamilyProjectionCalculator: #{mismatched.size} accounts have non-family currency, projections may be inaccurate"
      end

      # Calculate aggregate volatility from asset accounts for percentile bands
      volatility = aggregate_volatility(asset_accounts)

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

        # Calculate percentile bands using proper statistical methods
        percentiles = calculate_percentiles(net_worth, month, volatility)

        {
          date: date.iso8601,
          p10: percentiles[:p10],
          p25: percentiles[:p25],
          p50: percentiles[:p50],
          p75: percentiles[:p75],
          p90: percentiles[:p90],
          assets: projected_assets.to_f.round(2),
          liabilities: projected_liabilities.to_f.round(2)
        }
      end
    end

    # Calculate portfolio-weighted volatility from asset accounts
    def aggregate_volatility(asset_accounts)
      return 0.15 if asset_accounts.empty? # Default 15%

      total_balance = asset_accounts.sum(&:balance)
      return 0.15 if total_balance.zero?

      asset_accounts.sum do |account|
        assumption = ProjectionAssumption.for_account(account)
        weight = account.balance / total_balance
        volatility = assumption&.effective_volatility || 0.15
        weight * volatility
      end
    end

    # Calculate percentile bands using log-normal distribution
    # Handles both positive and negative net worth correctly
    # For positive: p10 (pessimistic) < p50 < p90 (optimistic)
    # For negative: p10 (more negative) < p50 < p90 (less negative)
    def calculate_percentiles(net_worth, month, volatility)
      time_factor = Math.sqrt(month / 12.0)
      sigma = volatility * time_factor

      if net_worth >= 0
        # Standard percentiles for positive net worth
        {
          p10: (net_worth * Math.exp(-1.28 * sigma)).to_f.round(2),
          p25: (net_worth * Math.exp(-0.67 * sigma)).to_f.round(2),
          p50: net_worth.to_f.round(2),
          p75: (net_worth * Math.exp(0.67 * sigma)).to_f.round(2),
          p90: (net_worth * Math.exp(1.28 * sigma)).to_f.round(2)
        }
      else
        # For negative net worth, invert the multipliers
        # p10 = pessimistic = more negative
        # p90 = optimistic = less negative
        abs_value = net_worth.abs
        {
          p10: -(abs_value * Math.exp(1.28 * sigma)).to_f.round(2),
          p25: -(abs_value * Math.exp(0.67 * sigma)).to_f.round(2),
          p50: net_worth.to_f.round(2),
          p75: -(abs_value * Math.exp(-0.67 * sigma)).to_f.round(2),
          p90: -(abs_value * Math.exp(-1.28 * sigma)).to_f.round(2)
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

      # Include extra payment from assumption
      base_payment = loan.monthly_payment&.amount || 0
      assumption = ProjectionAssumption.for_account(account)
      extra_payment = assumption&.extra_monthly_payment || 0
      payment = base_payment + extra_payment

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
