class CreateMessageFeedbacks < ActiveRecord::Migration[7.2]
  def change
    create_table :message_feedbacks, id: :uuid do |t|
      t.references :message, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment
      t.timestamps
    end

    add_index :message_feedbacks, [ :message_id, :user_id ], unique: true
  end
end
