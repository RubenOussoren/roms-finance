# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_11_185221) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "account_status", ["ok", "syncing", "error"]

  create_table "account_ownerships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.decimal "percentage", precision: 5, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id", "user_id"], name: "index_account_ownerships_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_account_ownerships_on_account_id"
    t.index ["user_id"], name: "index_account_ownerships_on_user_id"
  end

  create_table "account_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.string "visibility", default: "full", null: false
    t.index ["account_id", "user_id"], name: "index_account_permissions_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_account_permissions_on_account_id"
    t.index ["user_id", "visibility"], name: "index_account_permissions_on_user_id_and_visibility"
    t.index ["user_id"], name: "index_account_permissions_on_user_id"
  end

  create_table "account_projections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "actual_balance", precision: 19, scale: 4
    t.decimal "contribution", precision: 19, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.boolean "is_adaptive", default: false
    t.jsonb "metadata", default: {}
    t.jsonb "percentiles", default: {}
    t.decimal "projected_balance", precision: 19, scale: 4, null: false
    t.uuid "projection_assumption_id"
    t.date "projection_date", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "projection_date"], name: "index_account_projections_on_account_id_and_projection_date", unique: true
    t.index ["account_id"], name: "index_account_projections_on_account_id"
    t.index ["projection_assumption_id"], name: "index_account_projections_on_projection_assumption_id"
    t.index ["projection_date"], name: "index_account_projections_on_projection_date"
  end

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "accountable_id"
    t.string "accountable_type"
    t.decimal "balance", precision: 19, scale: 4
    t.decimal "cash_balance", precision: 19, scale: 4, default: "0.0"
    t.virtual "classification", type: :string, as: "\nCASE\n    WHEN ((accountable_type)::text = ANY (ARRAY[('Loan'::character varying)::text, ('CreditCard'::character varying)::text, ('OtherLiability'::character varying)::text])) THEN 'liability'::text\n    ELSE 'asset'::text\nEND", stored: true
    t.datetime "created_at", null: false
    t.uuid "created_by_user_id", null: false
    t.string "currency"
    t.uuid "family_id", null: false
    t.uuid "import_id"
    t.boolean "is_joint", default: false, null: false
    t.jsonb "locked_attributes", default: {}
    t.string "name"
    t.uuid "plaid_account_id"
    t.uuid "snaptrade_account_id"
    t.uuid "split_source_id"
    t.string "status", default: "active"
    t.string "subtype"
    t.datetime "updated_at", null: false
    t.index ["accountable_id", "accountable_type"], name: "index_accounts_on_accountable_id_and_accountable_type"
    t.index ["accountable_type"], name: "index_accounts_on_accountable_type"
    t.index ["currency"], name: "index_accounts_on_currency"
    t.index ["family_id", "accountable_type"], name: "index_accounts_on_family_id_and_accountable_type"
    t.index ["family_id", "created_by_user_id"], name: "index_accounts_on_family_id_and_created_by_user_id"
    t.index ["family_id", "id"], name: "index_accounts_on_family_id_and_id"
    t.index ["family_id", "status"], name: "index_accounts_on_family_id_and_status"
    t.index ["family_id"], name: "index_accounts_on_family_id"
    t.index ["import_id"], name: "index_accounts_on_import_id"
    t.index ["plaid_account_id"], name: "index_accounts_on_plaid_account_id"
    t.index ["snaptrade_account_id"], name: "index_accounts_on_snaptrade_account_id"
    t.index ["split_source_id"], name: "index_accounts_on_split_source_id"
    t.index ["status"], name: "index_accounts_on_status"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "addressable_id"
    t.string "addressable_type"
    t.string "country"
    t.string "county"
    t.datetime "created_at", null: false
    t.string "line1"
    t.string "line2"
    t.string "locality"
    t.integer "postal_code"
    t.string "region"
    t.datetime "updated_at", null: false
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
  end

  create_table "ai_memories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.uuid "family_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_ai_memories_on_expires_at"
    t.index ["family_id", "category"], name: "index_ai_memories_on_family_id_and_category"
    t.index ["family_id"], name: "index_ai_memories_on_family_id"
  end

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_key", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name"
    t.datetime "revoked_at"
    t.json "scopes"
    t.string "source", default: "web"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["display_key"], name: "index_api_keys_on_display_key", unique: true
    t.index ["revoked_at"], name: "index_api_keys_on_revoked_at"
    t.index ["user_id", "source"], name: "index_api_keys_on_user_id_and_source"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "balances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "balance", precision: 19, scale: 4, null: false
    t.decimal "cash_adjustments", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "cash_balance", precision: 19, scale: 4, default: "0.0"
    t.decimal "cash_inflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "cash_outflows", precision: 19, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "date", null: false
    t.virtual "end_balance", type: :decimal, precision: 19, scale: 4, as: "(((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments) + (((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments))", stored: true
    t.virtual "end_cash_balance", type: :decimal, precision: 19, scale: 4, as: "((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments)", stored: true
    t.virtual "end_non_cash_balance", type: :decimal, precision: 19, scale: 4, as: "(((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments)", stored: true
    t.integer "flows_factor", default: 1, null: false
    t.decimal "net_market_flows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_adjustments", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_inflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_outflows", precision: 19, scale: 4, default: "0.0", null: false
    t.virtual "start_balance", type: :decimal, precision: 19, scale: 4, as: "(start_cash_balance + start_non_cash_balance)", stored: true
    t.decimal "start_cash_balance", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "start_non_cash_balance", precision: 19, scale: 4, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "date", "currency"], name: "index_account_balances_on_account_id_date_currency_unique", unique: true
    t.index ["account_id", "date"], name: "index_balances_on_account_id_and_date", order: { date: :desc }
    t.index ["account_id"], name: "index_balances_on_account_id"
  end

  create_table "budget_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "budget_id", null: false
    t.decimal "budgeted_spending", precision: 19, scale: 4, null: false
    t.uuid "category_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_id", "category_id"], name: "index_budget_categories_on_budget_id_and_category_id", unique: true
    t.index ["budget_id"], name: "index_budget_categories_on_budget_id"
    t.index ["category_id"], name: "index_budget_categories_on_category_id"
  end

  create_table "budgets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "budgeted_spending", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.date "end_date", null: false
    t.decimal "expected_income", precision: 19, scale: 4
    t.uuid "family_id", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "start_date", "end_date"], name: "index_budgets_on_family_id_and_start_date_and_end_date", unique: true
    t.index ["family_id"], name: "index_budgets_on_family_id"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "classification", default: "expense", null: false
    t.string "color", default: "#6172F3", null: false
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "lucide_icon", default: "shapes", null: false
    t.string "name", null: false
    t.uuid "parent_id"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_categories_on_family_id"
  end

  create_table "chats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "error"
    t.string "instructions"
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "credit_cards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "annual_fee", precision: 10, scale: 2
    t.decimal "apr", precision: 10, scale: 2
    t.decimal "available_credit", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.date "expiration_date"
    t.jsonb "locked_attributes", default: {}
    t.decimal "minimum_payment", precision: 10, scale: 2
    t.datetime "updated_at", null: false
  end

  create_table "cryptos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "data_enrichments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "attribute_name"
    t.datetime "created_at", null: false
    t.uuid "enrichable_id", null: false
    t.string "enrichable_type", null: false
    t.jsonb "metadata"
    t.string "source"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["enrichable_id", "enrichable_type", "source", "attribute_name"], name: "idx_on_enrichable_id_enrichable_type_source_attribu_5be5f63e08", unique: true
    t.index ["enrichable_type", "enrichable_id"], name: "index_data_enrichments_on_enrichable"
  end

  create_table "debt_optimization_auto_stop_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "debt_optimization_strategy_id", null: false
    t.boolean "enabled", default: true, null: false
    t.jsonb "metadata", default: {}
    t.string "rule_type", null: false
    t.string "threshold_unit"
    t.decimal "threshold_value", precision: 19, scale: 4
    t.datetime "updated_at", null: false
    t.index ["debt_optimization_strategy_id", "rule_type"], name: "idx_debt_stop_rules_strategy_type", unique: true
    t.index ["debt_optimization_strategy_id"], name: "idx_on_debt_optimization_strategy_id_c57543b8d5"
  end

  create_table "debt_optimization_ledger_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "calendar_month", null: false
    t.datetime "created_at", null: false
    t.decimal "cumulative_tax_benefit", precision: 19, scale: 4, default: "0.0"
    t.uuid "debt_optimization_strategy_id", null: false
    t.decimal "deductible_interest", precision: 19, scale: 4, default: "0.0"
    t.decimal "heloc_balance", precision: 19, scale: 4, default: "0.0"
    t.decimal "heloc_draw", precision: 19, scale: 4, default: "0.0"
    t.decimal "heloc_interest", precision: 19, scale: 4, default: "0.0"
    t.decimal "heloc_interest_from_pocket", precision: 19, scale: 4, default: "0.0"
    t.decimal "heloc_interest_from_rental", precision: 19, scale: 4, default: "0.0"
    t.decimal "heloc_payment", precision: 19, scale: 4, default: "0.0"
    t.jsonb "metadata", default: {}
    t.integer "month_number", null: false
    t.decimal "net_rental_cash_flow", precision: 19, scale: 4, default: "0.0"
    t.decimal "net_worth_impact", precision: 19, scale: 4, default: "0.0"
    t.decimal "non_deductible_interest", precision: 19, scale: 4, default: "0.0"
    t.decimal "primary_mortgage_balance", precision: 19, scale: 4, default: "0.0"
    t.decimal "primary_mortgage_interest", precision: 19, scale: 4, default: "0.0"
    t.decimal "primary_mortgage_payment", precision: 19, scale: 4, default: "0.0"
    t.decimal "primary_mortgage_prepayment", precision: 19, scale: 4, default: "0.0"
    t.decimal "primary_mortgage_principal", precision: 19, scale: 4, default: "0.0"
    t.decimal "rental_expenses", precision: 19, scale: 4, default: "0.0"
    t.decimal "rental_income", precision: 19, scale: 4, default: "0.0"
    t.decimal "rental_mortgage_balance", precision: 19, scale: 4, default: "0.0"
    t.decimal "rental_mortgage_interest", precision: 19, scale: 4, default: "0.0"
    t.decimal "rental_mortgage_payment", precision: 19, scale: 4, default: "0.0"
    t.decimal "rental_mortgage_principal", precision: 19, scale: 4, default: "0.0"
    t.string "scenario_type", null: false
    t.string "stop_reason"
    t.boolean "strategy_stopped", default: false, null: false
    t.decimal "tax_benefit", precision: 19, scale: 4, default: "0.0"
    t.decimal "total_debt", precision: 19, scale: 4, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["debt_optimization_strategy_id", "month_number", "scenario_type"], name: "idx_debt_ledger_strategy_month_scenario", unique: true
    t.index ["debt_optimization_strategy_id"], name: "idx_on_debt_optimization_strategy_id_6b2b092cea"
  end

  create_table "debt_optimization_strategies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "CAD", null: false
    t.uuid "family_id", null: false
    t.uuid "heloc_id"
    t.decimal "heloc_interest_rate", precision: 6, scale: 4
    t.decimal "heloc_max_limit", precision: 19, scale: 4
    t.boolean "heloc_readvanceable", default: false
    t.uuid "jurisdiction_id"
    t.datetime "last_simulated_at"
    t.jsonb "metadata", default: {}
    t.integer "months_accelerated"
    t.string "name", null: false
    t.decimal "net_benefit", precision: 19, scale: 4
    t.uuid "primary_mortgage_id"
    t.string "province", limit: 2
    t.decimal "rental_expenses", precision: 19, scale: 4, default: "0.0"
    t.decimal "rental_income", precision: 19, scale: 4, default: "0.0"
    t.uuid "rental_mortgage_id"
    t.integer "simulation_months", default: 300
    t.string "status", default: "draft", null: false
    t.string "strategy_type", default: "baseline", null: false
    t.decimal "total_interest_saved", precision: 19, scale: 4
    t.decimal "total_tax_benefit", precision: 19, scale: 4
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_debt_optimization_strategies_on_family_id"
    t.index ["heloc_id"], name: "index_debt_optimization_strategies_on_heloc_id"
    t.index ["jurisdiction_id"], name: "index_debt_optimization_strategies_on_jurisdiction_id"
    t.index ["primary_mortgage_id"], name: "index_debt_optimization_strategies_on_primary_mortgage_id"
    t.index ["rental_mortgage_id"], name: "index_debt_optimization_strategies_on_rental_mortgage_id"
  end

  create_table "depositories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.datetime "created_at", null: false
    t.string "currency"
    t.date "date"
    t.uuid "entryable_id"
    t.string "entryable_type"
    t.boolean "excluded", default: false
    t.uuid "import_id"
    t.jsonb "locked_attributes", default: {}
    t.string "name", null: false
    t.text "notes"
    t.string "plaid_id"
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_entries_on_lower_name"
    t.index ["account_id", "date"], name: "index_entries_on_account_id_and_date"
    t.index ["account_id"], name: "index_entries_on_account_id"
    t.index ["date"], name: "index_entries_on_date"
    t.index ["entryable_type"], name: "index_entries_on_entryable_type"
    t.index ["import_id"], name: "index_entries_on_import_id"
  end

  create_table "equity_compensations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}, null: false
    t.datetime "updated_at", null: false
  end

  create_table "equity_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "cliff_months", default: 12
    t.datetime "created_at", null: false
    t.uuid "equity_compensation_id", null: false
    t.decimal "estimated_tax_rate", precision: 5, scale: 2
    t.date "expiration_date"
    t.date "grant_date", null: false
    t.decimal "grant_price", precision: 19, scale: 4
    t.string "grant_type", null: false
    t.string "name"
    t.string "option_type"
    t.uuid "security_id", null: false
    t.decimal "strike_price", precision: 19, scale: 4
    t.date "termination_date"
    t.decimal "total_units", precision: 19, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.string "vesting_frequency", default: "monthly"
    t.integer "vesting_period_months", null: false
    t.index ["equity_compensation_id"], name: "index_equity_grants_on_equity_compensation_id"
    t.index ["security_id"], name: "index_equity_grants_on_security_id"
  end

  create_table "exchange_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "from_currency", null: false
    t.decimal "rate", null: false
    t.string "to_currency", null: false
    t.datetime "updated_at", null: false
    t.index ["from_currency", "to_currency", "date"], name: "index_exchange_rates_on_base_converted_date_unique", unique: true
    t.index ["from_currency"], name: "index_exchange_rates_on_from_currency"
    t.index ["to_currency"], name: "index_exchange_rates_on_to_currency"
  end

  create_table "families", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "ai_profile", default: {}
    t.boolean "auto_sync_on_login", default: true, null: false
    t.string "country", default: "US"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD"
    t.boolean "data_enrichment_enabled", default: false
    t.string "date_format", default: "%m-%d-%Y"
    t.boolean "early_access", default: false
    t.datetime "latest_sync_activity_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "latest_sync_completed_at", default: -> { "CURRENT_TIMESTAMP" }
    t.string "locale", default: "en"
    t.string "name"
    t.string "snaptrade_user_id"
    t.string "snaptrade_user_secret"
    t.string "stripe_customer_id"
    t.string "timezone"
    t.datetime "updated_at", null: false
  end

  create_table "family_exports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "export_type", default: "full_data", null: false
    t.uuid "family_id", null: false
    t.uuid "requested_by_user_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_family_exports_on_family_id"
    t.index ["requested_by_user_id"], name: "index_family_exports_on_requested_by_user_id"
  end

  create_table "holdings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.date "date", null: false
    t.decimal "price", precision: 19, scale: 4, null: false
    t.decimal "qty", precision: 19, scale: 4, null: false
    t.uuid "security_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "security_id", "date", "currency"], name: "idx_on_account_id_security_id_date_currency_5323e39f8b", unique: true
    t.index ["account_id"], name: "index_holdings_on_account_id"
    t.index ["security_id"], name: "index_holdings_on_security_id"
  end

  create_table "impersonation_session_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action"
    t.string "controller"
    t.datetime "created_at", null: false
    t.uuid "impersonation_session_id", null: false
    t.string "ip_address"
    t.string "method"
    t.text "path"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.index ["impersonation_session_id"], name: "index_impersonation_session_logs_on_impersonation_session_id"
  end

  create_table "impersonation_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "impersonated_id", null: false
    t.uuid "impersonator_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["impersonated_id"], name: "index_impersonation_sessions_on_impersonated_id"
    t.index ["impersonator_id"], name: "index_impersonation_sessions_on_impersonator_id"
  end

  create_table "import_mappings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "create_when_empty", default: true
    t.datetime "created_at", null: false
    t.uuid "import_id", null: false
    t.string "key"
    t.uuid "mappable_id"
    t.string "mappable_type"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["import_id"], name: "index_import_mappings_on_import_id"
    t.index ["mappable_type", "mappable_id"], name: "index_import_mappings_on_mappable"
  end

  create_table "import_rows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account"
    t.string "amount"
    t.string "category"
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "date"
    t.string "entity_type"
    t.string "exchange_operating_mic"
    t.uuid "import_id", null: false
    t.string "name"
    t.text "notes"
    t.string "price"
    t.string "qty"
    t.string "tags"
    t.string "ticker"
    t.datetime "updated_at", null: false
    t.index ["import_id"], name: "index_import_rows_on_import_id"
  end

  create_table "imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_col_label"
    t.uuid "account_id"
    t.string "amount_col_label"
    t.string "amount_type_inflow_value"
    t.string "amount_type_strategy", default: "signed_amount"
    t.string "category_col_label"
    t.string "col_sep", default: ","
    t.jsonb "column_mappings"
    t.datetime "created_at", null: false
    t.string "currency_col_label"
    t.string "date_col_label"
    t.string "date_format", default: "%m/%d/%Y"
    t.string "entity_type_col_label"
    t.string "error"
    t.string "exchange_operating_mic_col_label"
    t.uuid "family_id", null: false
    t.string "name_col_label"
    t.string "normalized_csv_str"
    t.string "notes_col_label"
    t.string "number_format"
    t.string "price_col_label"
    t.string "qty_col_label"
    t.string "raw_file_str"
    t.string "signage_convention", default: "inflows_positive"
    t.string "status"
    t.string "tags_col_label"
    t.string "ticker_col_label"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["family_id"], name: "index_imports_on_family_id"
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "investments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "expires_at"
    t.uuid "family_id", null: false
    t.uuid "inviter_id", null: false
    t.string "role"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["email", "family_id"], name: "index_invitations_on_email_and_family_id", unique: true
    t.index ["email"], name: "index_invitations_on_email"
    t.index ["family_id"], name: "index_invitations_on_family_id"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "invite_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_invite_codes_on_token", unique: true
  end

  create_table "jurisdictions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country_code", null: false
    t.datetime "created_at", null: false
    t.string "currency_code", null: false
    t.boolean "has_smith_manoeuvre", default: false
    t.boolean "interest_deductible", default: false
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.jsonb "tax_config", default: {}
    t.datetime "updated_at", null: false
    t.index ["country_code"], name: "index_jurisdictions_on_country_code", unique: true
  end

  create_table "loans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "annual_lump_sum_amount", precision: 19, scale: 4
    t.integer "annual_lump_sum_month"
    t.date "calibrated_at"
    t.decimal "calibrated_balance", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 19, scale: 4
    t.decimal "initial_balance", precision: 19, scale: 4
    t.decimal "interest_rate", precision: 10, scale: 3
    t.jsonb "locked_attributes", default: {}
    t.date "origination_date"
    t.decimal "prepayment_privilege_percent", precision: 5, scale: 2
    t.string "rate_type"
    t.date "renewal_date"
    t.decimal "renewal_rate", precision: 10, scale: 3
    t.integer "renewal_term_months"
    t.integer "term_months"
    t.datetime "updated_at", null: false
  end

  create_table "merchants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.uuid "family_id"
    t.string "logo_url"
    t.string "name", null: false
    t.string "provider_merchant_id"
    t.string "source"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["family_id", "name"], name: "index_merchants_on_family_id_and_name", unique: true, where: "((type)::text = 'FamilyMerchant'::text)"
    t.index ["family_id"], name: "index_merchants_on_family_id"
    t.index ["source", "name"], name: "index_merchants_on_source_and_name", unique: true, where: "((type)::text = 'ProviderMerchant'::text)"
    t.index ["type"], name: "index_merchants_on_type"
  end

  create_table "message_feedbacks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.uuid "message_id", null: false
    t.integer "rating", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["message_id", "user_id"], name: "index_message_feedbacks_on_message_id_and_user_id", unique: true
    t.index ["message_id"], name: "index_message_feedbacks_on_message_id"
    t.index ["user_id"], name: "index_message_feedbacks_on_user_id"
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "ai_model"
    t.uuid "chat_id", null: false
    t.text "content"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.boolean "debug", default: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.string "provider_id"
    t.boolean "reasoning", default: false
    t.string "status", default: "complete", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "milestones", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.date "achieved_date"
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.boolean "is_custom", default: false
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.decimal "progress_percentage", precision: 6, scale: 2, default: "0.0"
    t.date "projected_date"
    t.decimal "starting_balance", precision: 19, scale: 4
    t.string "status", default: "pending"
    t.decimal "target_amount", precision: 19, scale: 4, null: false
    t.date "target_date"
    t.string "target_type", default: "reach", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_milestones_on_account_id_and_status"
    t.index ["account_id", "target_amount"], name: "index_milestones_on_account_id_and_target_amount", unique: true, where: "(is_custom = false)"
    t.index ["account_id"], name: "index_milestones_on_account_id"
    t.index ["status"], name: "index_milestones_on_status"
    t.index ["target_type"], name: "index_milestones_on_target_type"
  end

  create_table "mobile_devices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "app_version"
    t.datetime "created_at", null: false
    t.string "device_id"
    t.string "device_name"
    t.string "device_type"
    t.datetime "last_seen_at"
    t.integer "oauth_application_id"
    t.string "os_version"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["oauth_application_id"], name: "index_mobile_devices_on_oauth_application_id"
    t.index ["user_id", "device_id"], name: "index_mobile_devices_on_user_id_and_device_id", unique: true
    t.index ["user_id"], name: "index_mobile_devices_on_user_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.string "resource_owner_id"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "owner_id"
    t.string "owner_type"
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "other_assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "other_liabilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "plaid_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "available_balance", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.decimal "current_balance", precision: 19, scale: 4
    t.string "custom_name"
    t.string "mask"
    t.string "name", null: false
    t.string "plaid_id", null: false
    t.uuid "plaid_item_id", null: false
    t.string "plaid_subtype"
    t.string "plaid_type", null: false
    t.jsonb "raw_investments_payload", default: {}
    t.jsonb "raw_liabilities_payload", default: {}
    t.jsonb "raw_payload", default: {}
    t.jsonb "raw_transactions_payload", default: {}
    t.boolean "selected_for_import", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["plaid_id"], name: "index_plaid_accounts_on_plaid_id", unique: true
    t.index ["plaid_item_id"], name: "index_plaid_accounts_on_plaid_item_id"
  end

  create_table "plaid_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_token"
    t.string "available_products", default: [], array: true
    t.string "billed_products", default: [], array: true
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "institution_color"
    t.string "institution_id"
    t.string "institution_url"
    t.string "name"
    t.string "next_cursor"
    t.string "plaid_id", null: false
    t.string "plaid_region", default: "us", null: false
    t.jsonb "raw_institution_payload", default: {}
    t.jsonb "raw_payload", default: {}
    t.boolean "scheduled_for_deletion", default: false
    t.string "status", default: "good", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["family_id"], name: "index_plaid_items_on_family_id"
    t.index ["plaid_id"], name: "index_plaid_items_on_plaid_id", unique: true
    t.index ["user_id"], name: "index_plaid_items_on_user_id"
  end

  create_table "projection_assumptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id"
    t.datetime "created_at", null: false
    t.jsonb "custom_overrides", default: {}
    t.decimal "expected_return", precision: 6, scale: 4
    t.decimal "extra_monthly_payment", precision: 19, scale: 4, default: "0.0"
    t.uuid "family_id", null: false
    t.decimal "inflation_rate", precision: 6, scale: 4
    t.boolean "is_active", default: true
    t.jsonb "metadata", default: {}
    t.decimal "monthly_contribution", precision: 19, scale: 4, default: "0.0"
    t.string "name", null: false
    t.uuid "projection_standard_id"
    t.date "target_payoff_date"
    t.datetime "updated_at", null: false
    t.boolean "use_pag_defaults", default: true
    t.decimal "volatility", precision: 6, scale: 4
    t.index ["account_id"], name: "index_projection_assumptions_on_account_id"
    t.index ["account_id"], name: "index_projection_assumptions_unique_account", unique: true, where: "(account_id IS NOT NULL)"
    t.index ["family_id", "account_id"], name: "index_projection_assumptions_on_family_and_account"
    t.index ["family_id", "is_active"], name: "index_projection_assumptions_on_family_id_and_is_active", where: "(is_active = true)"
    t.index ["family_id"], name: "index_projection_assumptions_on_family_id"
    t.index ["projection_standard_id"], name: "index_projection_assumptions_on_projection_standard_id"
  end

  create_table "projection_standards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "cash_return", precision: 6, scale: 4
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "effective_year", null: false
    t.decimal "equity_return", precision: 6, scale: 4
    t.decimal "fixed_income_return", precision: 6, scale: 4
    t.decimal "inflation_rate", precision: 6, scale: 4
    t.uuid "jurisdiction_id", null: false
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.decimal "volatility_equity", precision: 6, scale: 4
    t.decimal "volatility_fixed_income", precision: 6, scale: 4
    t.index ["effective_year"], name: "index_projection_standards_on_effective_year"
    t.index ["jurisdiction_id", "code"], name: "index_projection_standards_on_jurisdiction_id_and_code", unique: true
    t.index ["jurisdiction_id"], name: "index_projection_standards_on_jurisdiction_id"
  end

  create_table "properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "area_unit"
    t.integer "area_value"
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
    t.integer "year_built"
  end

  create_table "rejected_transfers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "inflow_transaction_id", null: false
    t.uuid "outflow_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["inflow_transaction_id", "outflow_transaction_id"], name: "idx_on_inflow_transaction_id_outflow_transaction_id_412f8e7e26", unique: true
    t.index ["inflow_transaction_id"], name: "index_rejected_transfers_on_inflow_transaction_id"
    t.index ["outflow_transaction_id"], name: "index_rejected_transfers_on_outflow_transaction_id"
  end

  create_table "rule_actions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action_type", null: false
    t.datetime "created_at", null: false
    t.uuid "rule_id", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["rule_id"], name: "index_rule_actions_on_rule_id"
  end

  create_table "rule_conditions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "condition_type", null: false
    t.datetime "created_at", null: false
    t.string "operator", null: false
    t.uuid "parent_id"
    t.uuid "rule_id"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["parent_id"], name: "index_rule_conditions_on_parent_id"
    t.index ["rule_id"], name: "index_rule_conditions_on_rule_id"
  end

  create_table "rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.date "effective_date"
    t.uuid "family_id", null: false
    t.string "name"
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_rules_on_family_id"
  end

  create_table "securities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "exchange_acronym"
    t.string "exchange_mic"
    t.string "exchange_operating_mic"
    t.datetime "failed_fetch_at"
    t.integer "failed_fetch_count", default: 0, null: false
    t.datetime "last_health_check_at"
    t.string "logo_url"
    t.string "name"
    t.boolean "offline", default: false, null: false
    t.string "ticker", null: false
    t.datetime "updated_at", null: false
    t.index "upper((ticker)::text), COALESCE(upper((exchange_operating_mic)::text), ''::text)", name: "index_securities_on_ticker_and_exchange_operating_mic_unique", unique: true
    t.index ["country_code"], name: "index_securities_on_country_code"
    t.index ["exchange_operating_mic"], name: "index_securities_on_exchange_operating_mic"
  end

  create_table "security_prices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "date", null: false
    t.decimal "price", precision: 19, scale: 4, null: false
    t.uuid "security_id"
    t.datetime "updated_at", null: false
    t.index ["security_id", "date", "currency"], name: "index_security_prices_on_security_id_and_date_and_currency", unique: true
    t.index ["security_id"], name: "index_security_prices_on_security_id"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_impersonator_session_id"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.string "ip_address"
    t.jsonb "prev_transaction_page_params", default: {}
    t.datetime "subscribed_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["active_impersonator_session_id"], name: "index_sessions_on_active_impersonator_session_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.string "var", null: false
    t.index ["var"], name: "index_settings_on_var", unique: true
  end

  create_table "snaptrade_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.decimal "current_balance", precision: 19, scale: 4
    t.string "custom_name"
    t.string "name", null: false
    t.jsonb "raw_activities_payload", default: {}
    t.jsonb "raw_balances_payload", default: {}
    t.jsonb "raw_payload", default: {}
    t.jsonb "raw_positions_payload", default: {}
    t.boolean "selected_for_import", default: false, null: false
    t.string "snaptrade_account_id", null: false
    t.uuid "snaptrade_connection_id", null: false
    t.string "snaptrade_number"
    t.string "snaptrade_type"
    t.datetime "updated_at", null: false
    t.index ["snaptrade_account_id"], name: "index_snaptrade_accounts_on_snaptrade_account_id", unique: true
    t.index ["snaptrade_connection_id"], name: "index_snaptrade_accounts_on_snaptrade_connection_id"
  end

  create_table "snaptrade_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "authorization_id", null: false
    t.string "brokerage_name"
    t.string "brokerage_slug"
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.jsonb "raw_payload", default: {}
    t.boolean "scheduled_for_deletion", default: false
    t.string "status", default: "good", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["authorization_id"], name: "index_snaptrade_connections_on_authorization_id", unique: true
    t.index ["family_id"], name: "index_snaptrade_connections_on_family_id"
    t.index ["user_id"], name: "index_snaptrade_connections_on_user_id"
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 19, scale: 4
    t.datetime "created_at", null: false
    t.string "currency"
    t.datetime "current_period_ends_at"
    t.uuid "family_id", null: false
    t.string "interval"
    t.string "status", null: false
    t.string "stripe_id"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_subscriptions_on_family_id", unique: true
  end

  create_table "syncs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.string "error"
    t.datetime "failed_at"
    t.uuid "parent_id"
    t.datetime "pending_at"
    t.string "status", default: "pending"
    t.uuid "syncable_id", null: false
    t.string "syncable_type", null: false
    t.datetime "syncing_at"
    t.datetime "updated_at", null: false
    t.date "window_end_date"
    t.date "window_start_date"
    t.index ["parent_id"], name: "index_syncs_on_parent_id"
    t.index ["status"], name: "index_syncs_on_status"
    t.index ["syncable_type", "syncable_id"], name: "index_syncs_on_syncable"
  end

  create_table "taggings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "tag_id", null: false
    t.uuid "taggable_id"
    t.string "taggable_type"
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "color", default: "#e99537", null: false
    t.datetime "created_at", null: false
    t.uuid "family_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_tags_on_family_id"
  end

  create_table "tool_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "function_arguments"
    t.string "function_name"
    t.jsonb "function_result"
    t.uuid "message_id", null: false
    t.string "provider_call_id"
    t.string "provider_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
  end

  create_table "trades", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency"
    t.jsonb "locked_attributes", default: {}
    t.decimal "price", precision: 19, scale: 4
    t.decimal "qty", precision: 19, scale: 4
    t.uuid "security_id", null: false
    t.datetime "updated_at", null: false
    t.index ["security_id"], name: "index_trades_on_security_id"
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "category_id"
    t.datetime "created_at", null: false
    t.string "kind", default: "standard", null: false
    t.jsonb "locked_attributes", default: {}
    t.uuid "merchant_id"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["kind"], name: "index_transactions_on_kind"
    t.index ["merchant_id"], name: "index_transactions_on_merchant_id"
  end

  create_table "transfers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "inflow_transaction_id", null: false
    t.text "notes"
    t.uuid "outflow_transaction_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["inflow_transaction_id", "outflow_transaction_id"], name: "idx_on_inflow_transaction_id_outflow_transaction_id_8cd07a28bd", unique: true
    t.index ["inflow_transaction_id"], name: "index_transfers_on_inflow_transaction_id"
    t.index ["outflow_transaction_id"], name: "index_transfers_on_outflow_transaction_id"
    t.index ["status"], name: "index_transfers_on_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "ai_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.string "default_period", default: "last_30_days", null: false
    t.string "email"
    t.uuid "family_id", null: false
    t.string "first_name"
    t.text "goals", default: [], array: true
    t.string "last_name"
    t.uuid "last_viewed_chat_id"
    t.datetime "onboarded_at"
    t.string "otp_backup_codes", default: [], array: true
    t.boolean "otp_required", default: false, null: false
    t.string "otp_secret"
    t.string "password_digest"
    t.string "role", default: "member", null: false
    t.datetime "rule_prompt_dismissed_at"
    t.boolean "rule_prompts_disabled", default: false
    t.datetime "set_onboarding_goals_at"
    t.datetime "set_onboarding_preferences_at"
    t.boolean "show_ai_sidebar", default: true
    t.boolean "show_sidebar", default: true
    t.string "theme", default: "system"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["family_id"], name: "index_users_on_family_id"
    t.index ["last_viewed_chat_id"], name: "index_users_on_last_viewed_chat_id"
    t.index ["otp_secret"], name: "index_users_on_otp_secret", unique: true, where: "(otp_secret IS NOT NULL)"
  end

  create_table "valuations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", default: "reconciliation", null: false
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "vehicles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "make"
    t.string "mileage_unit"
    t.integer "mileage_value"
    t.string "model"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  add_foreign_key "account_ownerships", "accounts"
  add_foreign_key "account_ownerships", "users"
  add_foreign_key "account_permissions", "accounts"
  add_foreign_key "account_permissions", "users"
  add_foreign_key "account_projections", "accounts"
  add_foreign_key "account_projections", "projection_assumptions"
  add_foreign_key "accounts", "accounts", column: "split_source_id"
  add_foreign_key "accounts", "families"
  add_foreign_key "accounts", "imports"
  add_foreign_key "accounts", "plaid_accounts"
  add_foreign_key "accounts", "snaptrade_accounts"
  add_foreign_key "accounts", "users", column: "created_by_user_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_memories", "families"
  add_foreign_key "api_keys", "users"
  add_foreign_key "balances", "accounts", on_delete: :cascade
  add_foreign_key "budget_categories", "budgets"
  add_foreign_key "budget_categories", "categories"
  add_foreign_key "budgets", "families"
  add_foreign_key "categories", "families"
  add_foreign_key "chats", "users"
  add_foreign_key "debt_optimization_auto_stop_rules", "debt_optimization_strategies"
  add_foreign_key "debt_optimization_ledger_entries", "debt_optimization_strategies"
  add_foreign_key "debt_optimization_strategies", "accounts", column: "heloc_id"
  add_foreign_key "debt_optimization_strategies", "accounts", column: "primary_mortgage_id"
  add_foreign_key "debt_optimization_strategies", "accounts", column: "rental_mortgage_id"
  add_foreign_key "debt_optimization_strategies", "families"
  add_foreign_key "debt_optimization_strategies", "jurisdictions"
  add_foreign_key "entries", "accounts"
  add_foreign_key "entries", "imports"
  add_foreign_key "equity_grants", "equity_compensations", on_delete: :cascade
  add_foreign_key "equity_grants", "securities", on_delete: :cascade
  add_foreign_key "family_exports", "families"
  add_foreign_key "family_exports", "users", column: "requested_by_user_id"
  add_foreign_key "holdings", "accounts"
  add_foreign_key "holdings", "securities"
  add_foreign_key "impersonation_session_logs", "impersonation_sessions"
  add_foreign_key "impersonation_sessions", "users", column: "impersonated_id"
  add_foreign_key "impersonation_sessions", "users", column: "impersonator_id"
  add_foreign_key "import_rows", "imports"
  add_foreign_key "imports", "families"
  add_foreign_key "imports", "users"
  add_foreign_key "invitations", "families"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "merchants", "families"
  add_foreign_key "message_feedbacks", "messages"
  add_foreign_key "message_feedbacks", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "milestones", "accounts"
  add_foreign_key "mobile_devices", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "plaid_accounts", "plaid_items"
  add_foreign_key "plaid_items", "families"
  add_foreign_key "plaid_items", "users"
  add_foreign_key "projection_assumptions", "accounts"
  add_foreign_key "projection_assumptions", "families"
  add_foreign_key "projection_assumptions", "projection_standards"
  add_foreign_key "projection_standards", "jurisdictions"
  add_foreign_key "rejected_transfers", "transactions", column: "inflow_transaction_id"
  add_foreign_key "rejected_transfers", "transactions", column: "outflow_transaction_id"
  add_foreign_key "rule_actions", "rules"
  add_foreign_key "rule_conditions", "rule_conditions", column: "parent_id"
  add_foreign_key "rule_conditions", "rules"
  add_foreign_key "rules", "families"
  add_foreign_key "security_prices", "securities"
  add_foreign_key "sessions", "impersonation_sessions", column: "active_impersonator_session_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "snaptrade_accounts", "snaptrade_connections"
  add_foreign_key "snaptrade_connections", "families"
  add_foreign_key "snaptrade_connections", "users"
  add_foreign_key "subscriptions", "families"
  add_foreign_key "syncs", "syncs", column: "parent_id"
  add_foreign_key "taggings", "tags"
  add_foreign_key "tags", "families"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "trades", "securities"
  add_foreign_key "transactions", "categories", on_delete: :nullify
  add_foreign_key "transactions", "merchants"
  add_foreign_key "transfers", "transactions", column: "inflow_transaction_id", on_delete: :cascade
  add_foreign_key "transfers", "transactions", column: "outflow_transaction_id", on_delete: :cascade
  add_foreign_key "users", "chats", column: "last_viewed_chat_id"
  add_foreign_key "users", "families"
end
