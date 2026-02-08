class AccountPermission < ApplicationRecord
  VISIBILITIES = %w[full balance_only hidden].freeze

  belongs_to :account
  belongs_to :user

  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :user_id, uniqueness: { scope: :account_id }
  validate :user_is_not_account_owner
  validate :joint_account_must_be_full

  scope :for_user, ->(user) { where(user: user) }
  scope :full_access, -> { where(visibility: "full") }
  scope :balance_only, -> { where(visibility: "balance_only") }
  scope :hidden, -> { where(visibility: "hidden") }

  after_save :touch_account
  after_destroy :touch_account

  private

    def user_is_not_account_owner
      return unless account && user
      if account.created_by_user_id == user_id
        errors.add(:user, "cannot set permissions for the account owner")
      end
    end

    def joint_account_must_be_full
      return unless account
      if account.is_joint? && visibility != "full"
        errors.add(:visibility, "must be full for joint accounts")
      end
    end

    def touch_account
      account.touch
    end
end
