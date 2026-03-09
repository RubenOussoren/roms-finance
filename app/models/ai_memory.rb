class AiMemory < ApplicationRecord
  CATEGORIES = %w[preference goal context fact].freeze
  MAX_PER_FAMILY = 50

  belongs_to :family

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :content, presence: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :ordered, -> { order(created_at: :desc) }

  before_create :enforce_limit

  private

    def enforce_limit
      excess = family.ai_memories.count - MAX_PER_FAMILY + 1
      if excess > 0
        family.ai_memories.order(created_at: :asc).limit(excess).destroy_all
      end
    end
end
