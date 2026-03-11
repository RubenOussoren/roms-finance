class CreateEquityCompensations < ActiveRecord::Migration[7.2]
  def change
    create_table :equity_compensations, id: :uuid do |t|
      t.jsonb :locked_attributes, default: {}, null: false
      t.timestamps
    end
  end
end
