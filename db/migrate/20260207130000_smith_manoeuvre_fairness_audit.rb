class SmithManoeuvreFairnessAudit < ActiveRecord::Migration[7.2]
  def up
    # Task 4: scenario_type replaces baseline boolean
    add_column :debt_optimization_ledger_entries, :scenario_type, :string
    execute <<~SQL
      UPDATE debt_optimization_ledger_entries
      SET scenario_type = CASE WHEN baseline = true THEN 'baseline' ELSE 'modified_smith' END
    SQL
    change_column_null :debt_optimization_ledger_entries, :scenario_type, false
    remove_index :debt_optimization_ledger_entries,
      name: "idx_debt_ledger_strategy_month_baseline"
    remove_column :debt_optimization_ledger_entries, :baseline
    add_index :debt_optimization_ledger_entries,
      [ :debt_optimization_strategy_id, :month_number, :scenario_type ],
      unique: true, name: "idx_debt_ledger_strategy_month_scenario"

    # Task 1: HELOC interest source tracking
    add_column :debt_optimization_ledger_entries, :heloc_interest_from_rental,
      :decimal, precision: 19, scale: 4, default: 0
    add_column :debt_optimization_ledger_entries, :heloc_interest_from_pocket,
      :decimal, precision: 19, scale: 4, default: 0

    # Task 3: net benefit on strategies
    add_column :debt_optimization_strategies, :net_benefit,
      :decimal, precision: 19, scale: 4

    # Task 5: renewal term on loans
    add_column :loans, :renewal_term_months, :integer

    # Task 6: prepayment privilege on loans
    add_column :loans, :prepayment_privilege_percent,
      :decimal, precision: 5, scale: 2
  end

  def down
    add_column :debt_optimization_ledger_entries, :baseline, :boolean, default: false
    execute <<~SQL
      UPDATE debt_optimization_ledger_entries
      SET baseline = (scenario_type = 'baseline')
    SQL
    remove_index :debt_optimization_ledger_entries,
      name: "idx_debt_ledger_strategy_month_scenario"
    remove_column :debt_optimization_ledger_entries, :scenario_type
    add_index :debt_optimization_ledger_entries,
      [ :debt_optimization_strategy_id, :month_number, :baseline ],
      unique: true, name: "idx_debt_ledger_strategy_month_baseline"

    remove_column :debt_optimization_ledger_entries, :heloc_interest_from_rental
    remove_column :debt_optimization_ledger_entries, :heloc_interest_from_pocket
    remove_column :debt_optimization_strategies, :net_benefit
    remove_column :loans, :renewal_term_months
    remove_column :loans, :prepayment_privilege_percent
  end
end
