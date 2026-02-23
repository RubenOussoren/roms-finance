class AccountOwnership < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :user_id, uniqueness: { scope: :account_id }
  validate :user_in_same_family
  validate :total_percentage_within_limit

  after_save :touch_account
  after_destroy :touch_account

  private

    def user_in_same_family
      return unless account && user
      unless account.family_id == user.family_id
        errors.add(:user, "must be in the same family as the account")
      end
    end

    def total_percentage_within_limit
      return unless account && percentage.present?
      other_total = account.account_ownerships.where.not(id: id).sum(:percentage)
      if other_total + percentage > 100
        errors.add(:percentage, "total ownership cannot exceed 100%")
      end
    end

    def touch_account
      account.touch
    end
end
