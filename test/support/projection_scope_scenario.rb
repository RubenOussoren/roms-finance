module ProjectionScopeScenario
  def setup_projection_scope_scenario
    @viewer = users(:empty)
    @family = @viewer.family
    @visible = @family.accounts.create!(name: "Visible investment", balance: 100, currency: "USD",
      accountable: Investment.new, created_by_user: @viewer)
    @shared = @family.accounts.create!(name: "Balance-only asset", balance: 400, currency: "USD",
      accountable: OtherAsset.new, created_by_user: users(:new_email))
    @hidden = @family.accounts.create!(name: "Hidden asset", balance: 900, currency: "USD",
      accountable: OtherAsset.new, created_by_user: users(:new_email))
    @shared.account_permissions.create!(user: @viewer, visibility: "balance_only")
    @hidden.account_permissions.create!(user: @viewer, visibility: "hidden")
    @shared.account_ownerships.create!(user: @viewer, percentage: 25)
    @family.projection_assumptions.create!(name: "Synthetic family default",
      expected_return: 0, volatility: 0, use_pag_defaults: false)
    @family.projection_assumptions.create!(account: @visible, name: "Synthetic zero-return contributions",
      expected_return: 0, volatility: 0, monthly_contribution: 10, use_pag_defaults: false)
    [ @visible, @shared, @hidden ].each do |account|
      account.balances.create!(date: Date.current - 1.day, balance: account.balance, start_cash_balance: account.balance, currency: "USD")
    end
    # An unrelated family must never contribute to this viewer's overview.
    accounts(:other_asset).update!(balance: 7_000)
  end
end
