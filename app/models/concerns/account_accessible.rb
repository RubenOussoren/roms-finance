module AccountAccessible
  extend ActiveSupport::Concern

  included do
    scope :accessible_by, ->(user) {
      left_joins(:account_permissions)
        .where(
          "accounts.created_by_user_id = :uid OR " \
          "account_permissions.id IS NULL OR " \
          "(account_permissions.user_id = :uid AND account_permissions.visibility != 'hidden')",
          uid: user.id
        )
        .distinct
    }

    scope :full_access_for, ->(user) {
      left_joins(:account_permissions)
        .where(
          "accounts.created_by_user_id = :uid OR " \
          "(account_permissions.user_id = :uid AND account_permissions.visibility = 'full') OR " \
          "NOT EXISTS (SELECT 1 FROM account_permissions ap WHERE ap.account_id = accounts.id AND ap.user_id = :uid)",
          uid: user.id
        )
        .distinct
    }

    scope :balance_only_for, ->(user) {
      joins(:account_permissions)
        .where(account_permissions: { user_id: user.id, visibility: "balance_only" })
        .where.not(created_by_user_id: user.id)
    }

    scope :hidden_from, ->(user) {
      joins(:account_permissions)
        .where(account_permissions: { user_id: user.id, visibility: "hidden" })
        .where.not(created_by_user_id: user.id)
    }

    scope :owned_by, ->(user) {
      where(created_by_user_id: user.id)
    }
  end

  def owned_by?(user)
    created_by_user_id == user.id
  end

  def visibility_for(user)
    return :full if owned_by?(user)
    return :full if is_joint?

    permission = account_permissions.find_by(user_id: user.id)
    return :full if permission.nil?

    permission.visibility.to_sym
  end

  def accessible_by?(user)
    visibility_for(user) != :hidden
  end

  def full_access_for?(user)
    visibility_for(user) == :full
  end

  def balance_only_for?(user)
    visibility_for(user) == :balance_only
  end
end
