class Assistant::Function::GetBudgets < Assistant::Function
  class << self
    def name
      "get_budgets"
    end

    def description
      <<~INSTRUCTIONS
        Get the user's budget data with actuals vs planned spending.

        This is great for:
        - "How much have I spent this month?"
        - "Am I over budget?"
        - Comparing budgeted vs actual spending by category
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        month: {
          type: "string",
          description: "Month in YYYY-MM format (e.g., '2026-03'). Defaults to current month."
        }
      }
    )
  end

  def strict_mode?
    false
  end

  def call(params = {})
    start_date = if params["month"].present?
      safe_parse_date("#{params['month']}-01") || Date.current.beginning_of_month
    else
      Date.current.beginning_of_month
    end

    budget = Budget.find_or_bootstrap(family, start_date: start_date)

    return { error: "No budget found for #{start_date.strftime('%B %Y')}" } unless budget

    expense_categories = budget.budget_categories.includes(:category).select { |bc|
      bc.category&.classification == "expense" && bc.budgeted_spending.to_f > 0
    }

    {
      month: start_date.strftime("%B %Y"),
      currency: family.currency,
      expected_income: budget.estimated_income_money&.format,
      actual_income: budget.actual_income_money&.format,
      budgeted_spending: budget.allocated_spending_money&.format,
      actual_spending: budget.actual_spending_money&.format,
      available_to_spend: budget.available_to_spend_money&.format,
      percent_spent: budget.percent_of_budget_spent&.round(1),
      categories: expense_categories.map { |bc|
        {
          name: bc.name,
          budgeted: Money.new(bc.budgeted_spending, family.currency).format,
          actual: bc.actual_spending_money&.format,
          remaining: bc.available_to_spend_money&.format,
          percent_spent: bc.percent_of_budget_spent&.round(1)
        }
      }
    }
  end
end
