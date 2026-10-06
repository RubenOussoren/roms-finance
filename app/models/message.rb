class Message < ApplicationRecord
  belongs_to :chat
  has_many :tool_calls, dependent: :destroy
  has_one :feedback, class_name: "MessageFeedback", dependent: :destroy

  enum :status, {
    pending: "pending",
    complete: "complete",
    failed: "failed"
  }

  validates :content, presence: true, unless: -> { pending? || (is_a?(AssistantMessage) && failed?) }

  validate :response_identity_immutable, on: :update

  after_create_commit -> { broadcast_append_to chat, target: "messages" }, if: :broadcast?
  after_update_commit -> { broadcast_update_to chat }, if: :broadcast?

  scope :ordered, -> { order(created_at: :asc) }

  private
    def response_identity_immutable
      %w[chat_id type origin_user_message_id replaces_message_id attempt_number conversation_turn].each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
      if will_save_change_to_execution_claimed_at? && execution_claimed_at_in_database.present?
        errors.add(:execution_claimed_at, "cannot be changed once claimed")
      end
    end

    def broadcast?
      true
    end
end
