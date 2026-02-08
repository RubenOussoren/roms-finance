class MakeCreatedByUserIdNotNull < ActiveRecord::Migration[7.2]
  def change
    change_column_null :accounts, :created_by_user_id, false
  end
end
