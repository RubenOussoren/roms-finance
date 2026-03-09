class RemoveLatestAssistantResponseIdFromChats < ActiveRecord::Migration[7.2]
  def change
    remove_column :chats, :latest_assistant_response_id, :string
  end
end
