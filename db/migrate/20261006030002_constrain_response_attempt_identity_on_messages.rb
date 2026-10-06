class ConstrainResponseAttemptIdentityOnMessages < ActiveRecord::Migration[8.1]
  def up
    add_foreign_key :messages, :messages,
      column: [ :origin_user_message_id, :chat_id ], primary_key: [ :id, :chat_id ],
      name: "fk_messages_origin_in_chat", validate: false, deferrable: :deferred
    add_foreign_key :messages, :messages,
      column: [ :replaces_message_id, :chat_id ], primary_key: [ :id, :chat_id ],
      name: "fk_messages_replacement_in_chat", validate: false, deferrable: :deferred
  end

  def down
    remove_foreign_key :messages, name: "fk_messages_replacement_in_chat"
    remove_foreign_key :messages, name: "fk_messages_origin_in_chat"
  end
end
