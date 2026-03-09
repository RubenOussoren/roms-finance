class Assistant::Function::GetMilestones < Assistant::Function
  class << self
    def name
      "get_milestones"
    end

    def description
      <<~INSTRUCTIONS
        Get the user's financial milestones (goals) and progress toward each.

        This is great for:
        - "How close am I to my goals?"
        - "When will I reach $100K / $1M?"
        - Understanding goal progress and achievement dates
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        account_name: {
          type: "string",
          description: "Filter milestones to a specific account by name. Omit for all accounts."
        }
      }
    )
  end

  def strict_mode?
    false
  end

  def call(params = {})
    accounts = accessible_accounts
    if params["account_name"].present?
      accounts = accounts.where(name: params["account_name"])
    end

    milestones = Milestone.where(account: accounts).includes(:account).ordered_by_target

    {
      as_of_date: Date.current,
      total_milestones: milestones.size,
      milestones: milestones.map { |m|
        {
          name: m.name,
          account: m.account.name,
          target_amount: Money.new(m.target_amount, m.currency).format,
          currency: m.currency,
          target_type: m.target_type,
          status: m.status,
          progress_percentage: m.progress_percentage.round(1),
          is_custom: m.is_custom,
          projected_achievement_date: m.projected_date
        }
      }
    }
  end
end
