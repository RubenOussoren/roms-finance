class AccountPermissionsController < ApplicationController
  include StreamExtensions

  before_action :set_account
  before_action :ensure_multi_user_family
  before_action :ensure_account_owner

  def edit
    @family_members = Current.family.users.where.not(id: @account.created_by_user_id)
    @all_members = Current.family.users.order(:created_at)
    @permissions = @account.account_permissions.index_by(&:user_id)
    @ownerships = @account.account_ownerships.index_by(&:user_id)
  end

  def update
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.no_touching do
        update_permissions if params[:permissions].present?
        update_ownerships if params[:ownerships].present?
      end
    end
    @account.touch

    respond_to do |format|
      format.html { redirect_to account_path(@account), notice: "Settings updated" }
      format.turbo_stream { stream_redirect_to account_path(@account), notice: "Settings updated" }
    end
  rescue ActiveRecord::RecordInvalid => e
    @family_members = Current.family.users.where.not(id: @account.created_by_user_id)
    @all_members = Current.family.users.order(:created_at)
    @permissions = @account.account_permissions.index_by(&:user_id)
    @ownerships = @account.account_ownerships.index_by(&:user_id)
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
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

    def update_permissions
      permissions_params.each do |user_id, visibility|
        if visibility == "full"
          @account.account_permissions.where(user_id: user_id).destroy_all
        else
          permission = @account.account_permissions.find_or_initialize_by(user_id: user_id)
          permission.update!(visibility: visibility)
        end
      end
    end

    def update_ownerships
      total = ownerships_params.values.sum { |v| v.to_d }
      if total > 100
        raise ActiveRecord::RecordInvalid.new(
          AccountOwnership.new.tap { |o| o.errors.add(:percentage, "total ownership cannot exceed 100%") }
        )
      end

      @account.account_ownerships.reload

      ownerships_params.each do |user_id, pct_string|
        pct = pct_string.to_d
        ownership = @account.account_ownerships.find_or_initialize_by(user_id: user_id)

        if pct <= 0
          ownership.destroy! if ownership.persisted?
        else
          ownership.update!(percentage: pct)
        end
      end
    end

    def permissions_params
      params.require(:permissions).permit!.to_h
    end

    def ownerships_params
      params.require(:ownerships).permit!.to_h
    end
end
