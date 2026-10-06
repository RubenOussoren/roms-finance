class ValidateResponseAttemptIdentityOnMessages < ActiveRecord::Migration[8.1]
  def up
    # Run after FK installation has committed, releasing its stronger locks.
    validate_foreign_key :messages, name: "fk_messages_origin_in_chat"
    validate_foreign_key :messages, name: "fk_messages_replacement_in_chat"
    validate_check_constraint :messages, name: "messages_response_attempt_shape"
    validate_check_constraint :messages, name: "messages_conversation_turn_shape"
  end

  def down
    # Expansion rollback removes these constraints in the preceding migrations.
  end
end
