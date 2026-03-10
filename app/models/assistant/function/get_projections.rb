class Assistant::Function::GetProjections < Assistant::Function
  class << self
    def name
      "get_projections"
    end

    def description
      <<~INSTRUCTIONS
        Get future value projections for the user's accounts or entire portfolio.

        Returns projected values at various confidence levels (p10 through p90).

        This is great for:
        - "What will my portfolio be worth in 10 years?"
        - "Am I on track for retirement?"
        - Understanding growth potential with different scenarios
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [ "years" ],
      properties: {
        years: {
          type: "integer",
          description: "Number of years to project (1-30, default 10)"
        }
      }
    )
  end

  def call(params = {})
    years = (params["years"] || 10).to_i.clamp(1, 30)

    calculator = FamilyProjectionCalculator.new(family, viewer: user)
    result = calculator.project(years: years)

    summary = calculator.summary_metrics

    {
      as_of_date: Date.current,
      currency: result[:currency],
      current_net_worth: format_value(summary[:current_net_worth], result[:currency]),
      projection_years: years,
      projected_values: result[:projections]&.last(12)&.map { |p|
        {
          date: p[:date],
          p10: format_value(p[:p10], result[:currency]),
          p25: format_value(p[:p25], result[:currency]),
          p50: format_value(p[:p50], result[:currency]),
          p75: format_value(p[:p75], result[:currency]),
          p90: format_value(p[:p90], result[:currency])
        }
      },
      summary: result[:summary]
    }
  end

  private
    def format_value(value, currency)
      return nil unless value
      Money.new(value, currency).format
    end
end
