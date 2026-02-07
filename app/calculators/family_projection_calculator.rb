# Family-level net worth projection calculator
# Aggregates projections across all accounts for net worth trajectory
class FamilyProjectionCalculator
  include PercentileZScores

  DEFAULT_SAVINGS_RATE = 0.02

  # Default correlation assumptions for portfolio variance calculation
  # Used when per-asset-pair correlation data is unavailable
  SAME_CLASS_CORRELATION = 0.8   # e.g., equity-equity
  CROSS_CLASS_CORRELATION = 0.3  # e.g., equity-bonds

  attr_reader :family

  def initialize(family)
    @family = family
  end

  # Generate family-wide net worth projection
  # Results are cached for 1 hour and invalidated when account data changes
  def project(years:)
    cache_key = family.build_cache_key(
      "family_projection_#{years}",
      invalidate_on_data_updates: true
    )

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      months = years * 12
      historical = historical_net_worth_data
      projection_result = project_net_worth(months: months)
      projections = projection_result[:projections]

      result = {
        historical: historical,
        projections: projections,
        currency: family.currency,
        today: Date.current.iso8601,
        summary: build_summary(projections)
      }

      result[:currency_warnings] = projection_result[:currency_warnings] if projection_result[:currency_warnings].any?

      result
    end
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
      currency_warnings = []
      if mismatched.any?
        Rails.logger.warn "FamilyProjectionCalculator: #{mismatched.size} accounts have non-family currency, projections may be inaccurate"
        currency_warnings << "Mixed currencies detected — projections may be inaccurate. #{mismatched.size} account#{'s' if mismatched.size > 1} use#{'s' if mismatched.size == 1} non-#{family.currency} currencies."
      end

      # Calculate aggregate volatility from asset accounts for percentile bands
      volatility = aggregate_volatility(asset_accounts)

      # Build monthly projections
      projections = (1..months).map do |month|
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

      { projections: projections, currency_warnings: currency_warnings }
    end

    # Calculate portfolio volatility using the correct variance formula:
    # Var(portfolio) = sum_i(sum_j(w_i * w_j * sigma_i * sigma_j * rho_ij))
    # This captures diversification benefits between asset classes.
    def aggregate_volatility(asset_accounts)
      return 0.15 if asset_accounts.empty? # Default 15%

      total_balance = asset_accounts.sum(&:balance)
      return 0.15 if total_balance.zero?

      # Build arrays of weights, volatilities, and asset classes
      account_data = asset_accounts.map do |account|
        assumption = ProjectionAssumption.for_account(account)
        {
          weight: (account.balance / total_balance).to_f,
          volatility: (assumption&.effective_volatility || 0.15).to_f,
          asset_class: asset_class_for(account)
        }
      end

      # Portfolio variance = sum_i(sum_j(w_i * w_j * sigma_i * sigma_j * rho_ij))
      variance = 0.0
      account_data.each_with_index do |a, i|
        account_data.each_with_index do |b, j|
          rho = if i == j
            1.0  # Self-correlation is always 1
          else
            correlation_between(a[:asset_class], b[:asset_class])
          end
          variance += a[:weight] * b[:weight] * a[:volatility] * b[:volatility] * rho
        end
      end

      Math.sqrt([ variance, 0.0 ].max)
    end

    def asset_class_for(account)
      case account.accountable_type
      when "Investment", "Crypto" then :equity
      when "Depository" then :fixed_income
      else :equity
      end
    end

    def correlation_between(class_a, class_b)
      class_a == class_b ? SAME_CLASS_CORRELATION : CROSS_CLASS_CORRELATION
    end

    # Calculate percentile bands using log-normal distribution
    # Handles both positive and negative net worth correctly
    # For positive: p10 (pessimistic) < p50 < p90 (optimistic)
    # For negative: p10 (more negative) < p50 < p90 (less negative)
    # p50 uses drift correction: median = value * exp(-sigma²/2) for log-normal
    def calculate_percentiles(net_worth, month, volatility)
      time_factor = Math.sqrt(month / 12.0)
      sigma = volatility * time_factor
      drift_correction = Math.exp(-sigma**2 / 2.0)

      if net_worth >= 0
        # Standard percentiles for positive net worth
        {
          p10: (net_worth * Math.exp(Z_P10 * sigma)).to_f.round(2),
          p25: (net_worth * Math.exp(Z_P25 * sigma)).to_f.round(2),
          p50: (net_worth * drift_correction).to_f.round(2),
          p75: (net_worth * Math.exp(Z_P75 * sigma)).to_f.round(2),
          p90: (net_worth * Math.exp(Z_P90 * sigma)).to_f.round(2)
        }
      else
        # For negative net worth, invert the multipliers
        # p10 = pessimistic = more negative
        # p90 = optimistic = less negative
        abs_value = net_worth.abs
        {
          p10: -(abs_value * Math.exp(-Z_P10 * sigma)).to_f.round(2),
          p25: -(abs_value * Math.exp(-Z_P25 * sigma)).to_f.round(2),
          p50: -(abs_value * drift_correction).to_f.round(2),
          p75: -(abs_value * Math.exp(-Z_P75 * sigma)).to_f.round(2),
          p90: -(abs_value * Math.exp(-Z_P90 * sigma)).to_f.round(2)
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
        savings_rate = account.projection_assumption&.effective_return || DEFAULT_SAVINGS_RATE
        account.balance * (1 + savings_rate / 12) ** month
      else
        # Other accounts stay relatively flat
        account.balance
      end
    end

    def project_investment_balance(account, month)
      assumption = assumption_for(account)
      rate = assumption&.effective_return || 0.06
      contribution = assumption&.monthly_contribution || 0

      calculator = ProjectionCalculator.new(
        principal: account.balance,
        rate: rate,
        contribution: contribution,
        currency: account.currency
      )
      calculator.future_value_at_month(month)
    end

    # Per-account assumption caching to avoid N+1 queries
    # Each account may have its own assumption or fall back to family default
    def assumption_for(account)
      @assumption_cache ||= {}
      @assumption_cache[account.id] ||= ProjectionAssumption.for_account(account)
    end

    # Delegate to LoanPayoffCalculator for consistent amortization logic
    # LoanPayoffCalculator has memoization, making this efficient even when called multiple times
    def project_loan_balance(account, month)
      loan = account.accountable
      return account.balance if loan.nil?
      return 0 if account.balance <= 0

      assumption = assumption_for(account)
      extra_payment = assumption&.extra_monthly_payment || 0

      calculator = LoanPayoffCalculator.new(account, extra_payment: extra_payment)
      schedule = calculator.amortization_schedule

      entry = schedule.find { |e| e[:month] == month }
      entry ? entry[:balance] : 0
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
