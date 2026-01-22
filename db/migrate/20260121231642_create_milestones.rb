# Financial goal milestones ($100k, $500k, $1M, custom)
class CreateMilestones < ActiveRecord::Migration[7.2]
  def change
    create_table :milestones, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :target_amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false
      t.date :target_date
      t.date :projected_date
      t.date :achieved_date
      t.string :status, default: "pending"
      t.decimal :progress_percentage, precision: 6, scale: 2, default: 0
      t.boolean :is_custom, default: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :milestones, [ :account_id, :target_amount ], unique: true, where: "is_custom = false"
    add_index :milestones, :status
  end
end
