class CreateAiMemories < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_memories, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :category, null: false
      t.text :content, null: false
      t.datetime :expires_at

      t.timestamps
    end

    add_index :ai_memories, [ :family_id, :category ]
    add_index :ai_memories, :expires_at
  end
end
