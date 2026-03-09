class AddExportTypeToFamilyExports < ActiveRecord::Migration[7.2]
  def change
    add_column :family_exports, :export_type, :string, default: "full_data", null: false
    add_column :family_exports, :requested_by_user_id, :uuid
    add_index :family_exports, :requested_by_user_id
    add_foreign_key :family_exports, :users, column: :requested_by_user_id
  end
end
