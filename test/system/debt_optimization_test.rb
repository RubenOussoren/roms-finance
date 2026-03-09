require "application_system_test_case"

class DebtOptimizationTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    @smith_strategy = debt_optimization_strategies(:smith_manoeuvre)
    @baseline_strategy = debt_optimization_strategies(:baseline)
  end

  test "can view debt optimization strategies list" do
    visit debt_optimization_strategies_path

    assert_selector "h1", text: /Debt Optimization/
    assert_text @smith_strategy.name
    assert_text @baseline_strategy.name
  end

  test "can create modified smith manoeuvre strategy" do
    visit debt_optimization_strategies_path

    click_link "New Strategy"

    assert_text "New Debt Optimization Strategy"

    # Fill in basic strategy info
    fill_in "Strategy Name", with: "My Smith Manoeuvre Strategy"
    select "Modified Smith Manoeuvre", from: "Strategy Type"
    select "Ontario (ON)", from: "Province"

    # Link accounts
    select "Smith Primary Mortgage", from: "Primary Mortgage"
    select "Smith HELOC", from: "HELOC"
    select "Smith Rental Mortgage", from: "Rental Property Mortgage"

    # Rental property cash flow
    fill_in "debt_optimization_strategy[rental_income]", with: 2500
    fill_in "debt_optimization_strategy[rental_expenses]", with: 500
    fill_in "debt_optimization_strategy[heloc_interest_rate]", with: 7.0

    # Simulation settings
    fill_in "debt_optimization_strategy[simulation_months]", with: 120

    click_button "Create Strategy"

    # Should redirect to strategy show page
    assert_text "Strategy created successfully"
    assert_text "My Smith Manoeuvre Strategy"

    # Verify strategy configuration section shows linked accounts
    assert_text "Strategy Configuration"
    assert_text "Smith Primary Mortgage"
    assert_text "Smith HELOC"
    assert_text "Smith Rental Mortgage"
    assert_text "Ontario"
  end

  test "can run simulation on strategy" do
    visit debt_optimization_strategy_path(@smith_strategy)

    click_button "Run Simulation", match: :first

    assert_current_path debt_optimization_strategy_path(@smith_strategy)
    assert_text "Simulation completed successfully"
  end

  test "can simulate and view three-way comparison" do
    visit debt_optimization_strategy_path(@smith_strategy)

    # Run the simulation first
    click_button "Run Simulation", match: :first
    assert_text "Simulation completed successfully"

    # Verify 5 summary metrics appear (labels are CSS uppercase)
    assert_text(/net economic benefit/i)
    assert_text(/mortgage interest saved/i)
    assert_text(/tax benefit/i)
    assert_text(/heloc interest cost/i)
    assert_text(/time saved/i)

    # Verify 3 ledger tabs
    assert_text "Modified Smith"
    assert_text "Prepay Only"
    assert_text "Baseline"

    # Tax disclaimer mentions province
    assert_text "Ontario"

    # CRA tax documentation guide section exists for modified_smith type
    assert_text "Tax Documentation Guide"
    assert_text "CRA"
  end

  test "can view strategy details with simulation results" do
    visit debt_optimization_strategy_path(@baseline_strategy)

    assert_selector "h1", text: @baseline_strategy.name
    assert_text "Strategy Configuration"
  end

  test "can delete strategy" do
    visit debt_optimization_strategy_path(@smith_strategy)

    click_button "Delete Strategy"

    # Custom Turbo confirm dialog — click Confirm if it appears
    click_button "Confirm" if page.has_css?("#confirm-dialog[open]", wait: 2)

    assert_current_path debt_optimization_strategies_path
    assert_text "Strategy deleted successfully"
  end
end
