class AddSummaryToChats < ActiveRecord::Migration[7.2]
  def change
    add_column :chats, :summary, :text
  end
end
