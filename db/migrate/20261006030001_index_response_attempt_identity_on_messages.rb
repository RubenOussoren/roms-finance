class IndexResponseAttemptIdentityOnMessages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Composite reference keys let PostgreSQL enforce that links stay in-chat.
    add_index :messages, [ :id, :chat_id ], unique: true,
      name: "index_messages_on_id_and_chat", algorithm: :concurrently
    add_index :messages, [ :origin_user_message_id, :attempt_number ], unique: true,
      where: "origin_user_message_id IS NOT NULL",
      name: "index_messages_on_origin_and_attempt", algorithm: :concurrently
    add_index :messages, :replaces_message_id, unique: true,
      where: "replaces_message_id IS NOT NULL",
      name: "index_messages_on_replaced_attempt", algorithm: :concurrently
    add_index :messages, [ :chat_id, :conversation_turn ], unique: true,
      where: "conversation_turn IS NOT NULL",
      name: "index_messages_on_chat_and_turn", algorithm: :concurrently
  end
end
