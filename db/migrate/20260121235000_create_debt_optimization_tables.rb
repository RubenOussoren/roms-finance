# 🇨🇦 Canadian Modified Smith Manoeuvre - Database Schema
# 🔧 Extensibility: Architecture supports future US/UK debt optimization strategies
class CreateDebtOptimizationTables < ActiveRecord::Migration[7.2]
  def change
    # Main strategy configuration table
    create_table :debt_optimization_strategies, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.references :jurisdiction, type: :uuid, foreign_key: true
      t.references :primary_mortgage, type: :uuid, foreign_key: { to_table: :accounts }
      t.references :heloc, type: :uuid, foreign_key: { to_table: :accounts }
      t.references :rental_mortgage, type: :uuid, foreign_key: { to_table: :accounts }

      t.string :name, null: false
      t.string :strategy_type, null: false, default: "baseline"
      t.string :status, null: false, default: "draft"

      # Configuration
      t.decimal :rental_income, precision: 19, scale: 4, default: 0
      t.decimal :rental_expenses, precision: 19, scale: 4, default: 0
      t.decimal :heloc_interest_rate, precision: 6, scale: 4
      t.integer :simulation_months, default: 300 # 25 years

      # Cached results
      t.decimal :total_interest_saved, precision: 19, scale: 4
      t.decimal :total_tax_benefit, precision: 19, scale: 4
      t.integer :months_accelerated

      t.string :currency, null: false, default: "CAD"
      t.jsonb :metadata, default: {}
      t.datetime :last_simulated_at

      t.timestamps
    end

    # Month-by-month simulation results
    create_table :debt_optimization_ledger_entries, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :debt_optimization_strategy, type: :uuid, null: false, foreign_key: true

      t.integer :month_number, null: false
      t.date :calendar_month, null: false

      # Rental cash flows
      t.decimal :rental_income, precision: 19, scale: 4, default: 0
      t.decimal :rental_expenses, precision: 19, scale: 4, default: 0
      t.decimal :net_rental_cash_flow, precision: 19, scale: 4, default: 0

      # HELOC tracking
      t.decimal :heloc_draw, precision: 19, scale: 4, default: 0
      t.decimal :heloc_balance, precision: 19, scale: 4, default: 0
      t.decimal :heloc_interest, precision: 19, scale: 4, default: 0
      t.decimal :heloc_payment, precision: 19, scale: 4, default: 0

      # Primary mortgage tracking
      t.decimal :primary_mortgage_balance, precision: 19, scale: 4, default: 0
      t.decimal :primary_mortgage_payment, precision: 19, scale: 4, default: 0
      t.decimal :primary_mortgage_principal, precision: 19, scale: 4, default: 0
      t.decimal :primary_mortgage_interest, precision: 19, scale: 4, default: 0
      t.decimal :primary_mortgage_prepayment, precision: 19, scale: 4, default: 0

      # Rental mortgage tracking
      t.decimal :rental_mortgage_balance, precision: 19, scale: 4, default: 0
      t.decimal :rental_mortgage_payment, precision: 19, scale: 4, default: 0
      t.decimal :rental_mortgage_principal, precision: 19, scale: 4, default: 0
      t.decimal :rental_mortgage_interest, precision: 19, scale: 4, default: 0

      # Tax calculations
      t.decimal :deductible_interest, precision: 19, scale: 4, default: 0
      t.decimal :non_deductible_interest, precision: 19, scale: 4, default: 0
      t.decimal :tax_benefit, precision: 19, scale: 4, default: 0
      t.decimal :cumulative_tax_benefit, precision: 19, scale: 4, default: 0

      # Totals
      t.decimal :total_debt, precision: 19, scale: 4, default: 0
      t.decimal :net_worth_impact, precision: 19, scale: 4, default: 0

      # Flags
      t.boolean :baseline, default: false, null: false
      t.boolean :strategy_stopped, default: false, null: false
      t.string :stop_reason

      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :debt_optimization_ledger_entries,
              [ :debt_optimization_strategy_id, :month_number, :baseline ],
              unique: true,
              name: "idx_debt_ledger_strategy_month_baseline"

    # Auto-stop rules for strategies
    create_table :debt_optimization_auto_stop_rules, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :debt_optimization_strategy, type: :uuid, null: false, foreign_key: true

      t.string :rule_type, null: false
      t.decimal :threshold_value, precision: 19, scale: 4
      t.string :threshold_unit # "percentage", "amount", "months"
      t.boolean :enabled, default: true, null: false

      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :debt_optimization_auto_stop_rules,
              [ :debt_optimization_strategy_id, :rule_type ],
              unique: true,
              name: "idx_debt_stop_rules_strategy_type"

    # Add credit_limit to loans table for HELOC tracking
    add_column :loans, :credit_limit, :decimal, precision: 19, scale: 4
  end
end
