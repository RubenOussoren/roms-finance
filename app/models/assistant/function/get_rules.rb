class Assistant::Function::GetRules < Assistant::Function
  class << self
    def name
      "get_rules"
    end

    def description
      "Get the user's transaction automation rules with their conditions and actions."
    end
  end

  def call(params = {})
    rules = family.rules.includes(:conditions, :actions)

    {
      total_rules: rules.size,
      rules: rules.map { |rule|
        {
          name: rule.name,
          conditions: rule.conditions.map { |c|
            { field: c.condition_type, operator: c.operator, value: c.value }
          },
          actions: rule.actions.map { |a|
            { type: a.action_type, value: a.value }
          }
        }
      }
    }
  end
end
