class BackfillAccountOwnership < ActiveRecord::Migration[7.2]
  def up
    Family.find_each do |family|
      users = family.users.order(:created_at)
      next if users.empty?

      owner = users.find { |u| u.role == "admin" || u.role == "super_admin" } || users.first
      family.accounts.where(created_by_user_id: nil).update_all(created_by_user_id: owner.id)
    end
  end

  def down
    Account.update_all(created_by_user_id: nil)
  end
end
