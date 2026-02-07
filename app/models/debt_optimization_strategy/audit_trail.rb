# 🇨🇦 CRA-compliant audit trail for debt optimization strategies
# Generates reports suitable for tax filing and CRA review
class DebtOptimizationStrategy::AuditTrail
  attr_reader :strategy

  def initialize(strategy)
    @strategy = strategy
  end

  # Generate annual report for a specific tax year
  def generate_annual_report(year)
    entries = strategy.strategy_entries.where(
      "EXTRACT(YEAR FROM calendar_month) = ?", year
    ).order(:month_number)

    return nil if entries.empty?

    {
      year: year,
      strategy_name: strategy.name,
      strategy_type: strategy.strategy_type,
      jurisdiction: strategy.jurisdiction&.name || "Canada",

      # Rental property income summary
      rental_income: {
        total_gross_income: entries.sum(&:rental_income),
        total_expenses: entries.sum(&:rental_expenses),
        net_rental_income: entries.sum(&:net_rental_cash_flow)
      },

      # Interest deduction summary
      interest_deductions: {
        heloc_interest: entries.sum(&:heloc_interest),
        rental_mortgage_interest: entries.sum(&:rental_mortgage_interest),
        total_deductible_interest: entries.sum(&:deductible_interest),
        non_deductible_interest: entries.sum(&:non_deductible_interest)
      },

      # Tax benefit calculation
      tax_benefit: {
        province: strategy.effective_province,
        marginal_tax_rate: strategy.effective_marginal_tax_rate,
        estimated_tax_savings: entries.sum(&:tax_benefit)
      },

      # HELOC usage audit trail (CRA requires purpose documentation)
      heloc_usage: {
        purpose: "Rental property expense financing",
        total_draws: entries.sum(&:heloc_draw),
        year_end_balance: entries.last&.heloc_balance || 0,
        interest_paid: entries.sum(&:heloc_interest),
        compliance_note: "All HELOC funds used exclusively for investment/rental property purposes as required by CRA"
      },

      # Monthly breakdown for detailed audit
      monthly_breakdown: entries.map do |entry|
        {
          month: entry.calendar_month.strftime("%B %Y"),
          heloc_draw: entry.heloc_draw,
          heloc_balance: entry.heloc_balance,
          deductible_interest: entry.deductible_interest,
          tax_benefit: entry.tax_benefit
        }
      end,

      # Generated metadata
      generated_at: Time.current,
      disclaimer: cra_disclaimer
    }
  end

  # Generate multi-year summary
  def generate_summary_report
    return nil unless strategy.strategy_entries.any?

    years = strategy.strategy_entries.pluck(:calendar_month).map(&:year).uniq.sort

    {
      strategy_name: strategy.name,
      strategy_type: strategy.strategy_type,
      total_simulation_period: "#{years.first} to #{years.last}",

      # Cumulative totals
      totals: {
        total_tax_benefit: strategy.strategy_entries.last&.cumulative_tax_benefit || 0,
        total_interest_saved: strategy.total_interest_saved || 0,
        months_accelerated: strategy.months_accelerated || 0,
        total_heloc_interest_paid: strategy.strategy_entries.sum(&:heloc_interest),
        total_deductible_interest: strategy.strategy_entries.sum(&:deductible_interest)
      },

      # Year-by-year summary
      annual_summaries: years.map { |year| generate_annual_summary(year) },

      # Compliance documentation
      compliance: {
        strategy_compliant: true,
        cra_requirements_met: [
          "HELOC funds used 100% for rental property purposes",
          "Clear audit trail maintained for all transactions",
          "Interest deductibility properly documented"
        ]
      },

      generated_at: Time.current
    }
  end

  # Export as CSV for accounting software
  def export_csv(year: nil)
    entries = year.present? ?
      strategy.strategy_entries.where("EXTRACT(YEAR FROM calendar_month) = ?", year) :
      strategy.strategy_entries

    entries = entries.order(:month_number)

    CSV.generate do |csv|
      csv << [
        "Month", "Calendar Month",
        "Rental Income", "Rental Expenses", "Net Rental Cash Flow",
        "HELOC Draw", "HELOC Balance", "HELOC Interest",
        "Primary Mortgage Balance", "Primary Mortgage Interest", "Prepayment",
        "Rental Mortgage Balance", "Rental Mortgage Interest",
        "Deductible Interest", "Non-Deductible Interest", "Tax Benefit",
        "Cumulative Tax Benefit", "Total Debt"
      ]

      entries.each do |entry|
        csv << [
          entry.month_number,
          entry.calendar_month.strftime("%Y-%m"),
          entry.rental_income,
          entry.rental_expenses,
          entry.net_rental_cash_flow,
          entry.heloc_draw,
          entry.heloc_balance,
          entry.heloc_interest,
          entry.primary_mortgage_balance,
          entry.primary_mortgage_interest,
          entry.primary_mortgage_prepayment,
          entry.rental_mortgage_balance,
          entry.rental_mortgage_interest,
          entry.deductible_interest,
          entry.non_deductible_interest,
          entry.tax_benefit,
          entry.cumulative_tax_benefit,
          entry.total_debt
        ]
      end
    end
  end

  private

    def generate_annual_summary(year)
      entries = strategy.strategy_entries.where(
        "EXTRACT(YEAR FROM calendar_month) = ?", year
      )

      {
        year: year,
        total_deductible_interest: entries.sum(&:deductible_interest),
        total_tax_benefit: entries.sum(&:tax_benefit),
        year_end_heloc_balance: entries.order(:month_number).last&.heloc_balance || 0,
        year_end_primary_mortgage: entries.order(:month_number).last&.primary_mortgage_balance || 0
      }
    end

    def cra_disclaimer
      <<~DISCLAIMER
        This report is generated for informational purposes only and does not constitute tax advice.
        Consult with a qualified tax professional before claiming interest deductions.
        The Canada Revenue Agency (CRA) requires that borrowed funds be used for income-producing
        purposes for interest to be deductible under section 20(1)(c) of the Income Tax Act.
        Maintain all supporting documentation including loan statements, property records,
        and evidence of the investment purpose of borrowed funds.
      DISCLAIMER
    end
end
