# User-customizable projection assumptions
class CreateProjectionAssumptions < ActiveRecord::Migration[7.2]
  def change
    create_table :projection_assumptions, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.references :projection_standard, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.decimal :expected_return, precision: 6, scale: 4
      t.decimal :inflation_rate, precision: 6, scale: 4
      t.decimal :monthly_contribution, precision: 19, scale: 4, default: 0
      t.decimal :volatility, precision: 6, scale: 4
      t.boolean :use_pag_defaults, default: true
      t.boolean :is_active, default: true
      t.jsonb :custom_overrides, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :projection_assumptions, [ :family_id, :is_active ], where: "is_active = true"
  end
end
