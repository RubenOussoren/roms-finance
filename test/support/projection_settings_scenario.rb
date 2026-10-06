module ProjectionSettingsScenario
  def setup_projection_settings_scenario
    @viewer = users(:empty)
    @family = @viewer.family
    owner = users(:new_email)
    @family.update!(currency: "USD")

    @investment = @family.accounts.create!(name: "Synthetic settings investment",
      balance: 100, currency: "USD", accountable: Investment.new, created_by_user: @viewer)
    @shared = @family.accounts.create!(name: "Synthetic shared investment",
      balance: 400, currency: "USD", accountable: Investment.new, created_by_user: owner)
    @hidden = @family.accounts.create!(name: "Synthetic hidden investment",
      balance: 900, currency: "USD", accountable: Investment.new, created_by_user: owner)
    @shared.account_permissions.create!(user: @viewer, visibility: "full")
    @shared.account_ownerships.create!(user: @viewer, percentage: 25)
    @hidden.account_permissions.create!(user: @viewer, visibility: "hidden")

    @family.projection_assumptions.create!(name: "Synthetic settings family default",
      expected_return: 0, volatility: 0, monthly_contribution: 10,
      use_pag_defaults: false, is_active: true)
    [ @investment, @shared, @hidden ].each do |account|
      account.balances.create!(date: Date.current - 1.day, balance: account.balance,
        start_cash_balance: account.balance, currency: "USD")
    end
  end
end
