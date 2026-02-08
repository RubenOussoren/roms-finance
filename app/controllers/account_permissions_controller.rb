class AccountPermissionsController < ApplicationController
  before_action :set_account
  before_action :ensure_multi_user_family
  before_action :ensure_account_owner

  def edit
    @family_members = Current.family.users.where.not(id: @account.created_by_user_id)
    @permissions = @account.account_permissions.index_by(&:user_id)
  end

  def update
    AccountPermission.transaction do
      permissions_params.each do |user_id, visibility|
        if visibility == "full"
          @account.account_permissions.where(user_id: user_id).destroy_all
        else
          permission = @account.account_permissions.find_or_initialize_by(user_id: user_id)
          permission.update!(visibility: visibility)
        end
      end
    end

    redirect_to account_path(@account), notice: "Privacy settings updated"
  end

  private

    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def ensure_multi_user_family
      head :not_found unless Current.family.multi_user?
    end

    def ensure_account_owner
      unless @account.owned_by?(Current.user)
        redirect_to account_path(@account), alert: "Only the account owner can manage privacy settings"
      end
    end

    def permissions_params
      params.require(:permissions).permit!.to_h
    end
end
