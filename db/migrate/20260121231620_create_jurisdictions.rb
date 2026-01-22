# 🇨🇦 Canadian-first jurisdiction registry
# 🔧 Extensibility: Architecture supports future US/UK expansion
class CreateJurisdictions < ActiveRecord::Migration[7.2]
  def change
    create_table :jurisdictions, id: :uuid do |t|
      t.string :country_code, null: false
      t.string :name, null: false
      t.string :currency_code, null: false
      t.boolean :interest_deductible, default: false
      t.boolean :has_smith_manoeuvre, default: false
      t.jsonb :tax_config, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :jurisdictions, :country_code, unique: true
  end
end
