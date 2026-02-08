module FinanceTooltipHelper
  FINANCIAL_TERMS = {
    "Volatility" => "How much your investments might swing up or down in any given year — higher means more unpredictable",
    "Monte Carlo simulation" => "We run thousands of 'what-if' scenarios to show you a range of possible outcomes, not just one prediction",
    "PAG 2025" => "Canadian financial planning standards that use conservative assumptions so your plan is realistic",
    "HELOC" => "Home Equity Line of Credit — a flexible borrowing account secured by the equity in your home",
    "Modified Smith Manoeuvre" => "A strategy to make your mortgage interest tax-deductible by using a HELOC to invest",
    "Blended return" => "The weighted average growth rate across all your different investments",
    "p10/p50/p90" => "The pessimistic (p10), middle (p50), and optimistic (p90) scenarios from our simulations",
    "Inflation rate" => "How much the cost of living tends to increase each year, which reduces the future value of your money",
    "Real return" => "Your investment growth after subtracting inflation — what your money can actually buy",
    "Net worth" => "Everything you own (assets) minus everything you owe (debts)",
    "Expected return" => "The average yearly growth rate you anticipate for this investment, before inflation",
    "Monthly contribution" => "How much you plan to add to this account each month",
    "Net Economic Benefit" => "The total financial advantage of this strategy — interest saved plus tax benefits minus costs",
    "Tax deductible interest" => "Interest payments that can reduce your taxable income, lowering what you owe in taxes",
    "Projection horizon" => "How many years into the future to project your finances"
  }.freeze

  def finance_tooltip(term, placement: "top")
    definition = FINANCIAL_TERMS[term]
    return "" unless definition
    render DS::Tooltip.new(text: definition, placement: placement)
  end
end
