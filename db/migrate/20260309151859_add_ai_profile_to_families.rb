class AddAiProfileToFamilies < ActiveRecord::Migration[7.2]
  def change
    add_column :families, :ai_profile, :jsonb, default: {}
  end
end
