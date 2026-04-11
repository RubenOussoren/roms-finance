class AddTokenCountsToMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :messages, :input_tokens, :integer
    add_column :messages, :output_tokens, :integer
    add_column :messages, :cost_cents, :integer
  end
end
