class UserMessage < Message
  validates :ai_model, presence: true

  validates :conversation_turn, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  around_create :assign_conversation_turn

  after_create_commit :request_response_later

  def role
    "user"
  end

  def request_response_later
    chat.ask_assistant_later(self)
  end

  def request_response
    chat.ask_assistant(self)
  end

  private
    def assign_conversation_turn
      chat.with_lock do
        self.conversation_turn = (chat.messages.maximum(:conversation_turn) || 0) + 1
        yield
      end
    end
end
