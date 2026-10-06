class AddResponseAttemptIdentityToMessages < ActiveRecord::Migration[8.1]
  def change
    # Nullable, without defaults: legacy transcripts are retained, never guessed.
    add_column :messages, :origin_user_message_id, :uuid
    add_column :messages, :replaces_message_id, :uuid
    add_column :messages, :attempt_number, :integer
    add_column :messages, :execution_claimed_at, :datetime
    add_column :messages, :conversation_turn, :integer

    add_check_constraint :messages, <<~SQL.squish, name: "messages_response_attempt_shape", validate: false
      (
        origin_user_message_id IS NULL AND attempt_number IS NULL
        AND replaces_message_id IS NULL AND execution_claimed_at IS NULL
      ) OR (
        type = 'AssistantMessage' AND origin_user_message_id IS NOT NULL
        AND attempt_number IS NOT NULL AND attempt_number > 0
        AND conversation_turn IS NULL AND origin_user_message_id <> id
        AND (
          (attempt_number = 1 AND replaces_message_id IS NULL)
          OR (attempt_number > 1 AND replaces_message_id IS NOT NULL AND replaces_message_id <> id)
        )
      )
    SQL

    add_check_constraint :messages, <<~SQL.squish, name: "messages_conversation_turn_shape", validate: false
      conversation_turn IS NULL OR (type = 'UserMessage' AND conversation_turn > 0)
    SQL
  end
end
