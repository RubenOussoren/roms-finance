require_relative "projection_settings_scenario"

module ProjectionContributionScenario
  include ProjectionSettingsScenario

  def setup_projection_contribution_scenario
    setup_projection_settings_scenario
    # Synthetic rates: blended 0.5% minus the existing 0.5% safety margin = 0%.
    # This is a deterministic cash-flow oracle, not a published guideline forecast.
    @standard = ProjectionStandard.create!(jurisdiction: jurisdictions(:canada),
      name: "Synthetic zero-return standard", code: "SYNTHETIC_CONTRIBUTIONS",
      effective_year: 2025, equity_return: 0.005, fixed_income_return: 0.005,
      cash_return: 0.005, inflation_rate: 0.02, volatility_equity: 0)
    @family_assumption = @family.projection_assumptions.family_default.sole
    @family_assumption.update!(projection_standard: @standard, monthly_contribution: 100)
    @assumption = ProjectionAssumption.create_for_account(@investment,
      monthly_contribution: 100)
    @assumption.update!(extra_monthly_payment: 25)
  end
end
