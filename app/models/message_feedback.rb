class MessageFeedback < ApplicationRecord
  belongs_to :message
  belongs_to :user

  enum :rating, { thumbs_down: 0, thumbs_up: 1 }

  validates :rating, presence: true
  validates :message_id, uniqueness: { scope: :user_id }
end
