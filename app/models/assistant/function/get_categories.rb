class Assistant::Function::GetCategories < Assistant::Function
  class << self
    def name
      "get_categories"
    end

    def description
      <<~INSTRUCTIONS
        Get the user's category tree with spending totals.

        This is great for:
        - "What are my spending categories?"
        - "Where am I spending the most money?"
        - Understanding category hierarchy and allocation
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        period: {
          type: "string",
          description: "Time period: 'this_month', 'last_month', 'last_3_months', 'this_year'. Defaults to 'this_month'."
        }
      }
    )
  end

  def strict_mode?
    false
  end

  def call(params = {})
    period_range = resolve_period(params["period"] || "this_month")

    categories = family.categories.includes(:subcategories)
    parent_categories = categories.where(parent_id: nil)

    account_ids = full_access_accounts.pluck(:id)

    {
      period: params["period"] || "this_month",
      currency: family.currency,
      categories: parent_categories.map { |cat|
        spending = category_spending(cat, account_ids, period_range)
        subcats = cat.subcategories.map { |sub|
          sub_spending = category_spending(sub, account_ids, period_range)
          { name: sub.name, classification: sub.classification, spending: sub_spending }
        }.select { |s| s[:spending].to_f > 0 }

        {
          name: cat.name,
          classification: cat.classification,
          spending: spending,
          subcategories: subcats
        }
      }.select { |c| c[:spending].to_f > 0 || c[:subcategories].any? }
    }
  end

  private
    def category_spending(category, account_ids, period_range)
      Entry.joins(:transaction)
           .where(account_id: account_ids)
           .where(date: period_range)
           .where(transactions: { category_id: category.id })
           .where("entries.amount > 0")
           .sum(:amount)
           .then { |sum| Money.new(sum, family.currency).format }
    end

    def resolve_period(period_name)
      case period_name
      when "last_month"
        1.month.ago.beginning_of_month..1.month.ago.end_of_month
      when "last_3_months"
        3.months.ago.beginning_of_month..Date.current
      when "this_year"
        Date.current.beginning_of_year..Date.current
      else
        Date.current.beginning_of_month..Date.current
      end
    end
end
