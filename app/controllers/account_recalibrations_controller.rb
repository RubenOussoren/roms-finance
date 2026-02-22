class AccountRecalibrationsController < ApplicationController
  before_action :set_account
  before_action :ensure_loan_account

  def new
  end

  def create
    balance = recalibration_params[:balance].to_d
    date = recalibration_params[:date].present? ? Date.parse(recalibration_params[:date]) : Date.current

    @account.accountable.recalibrate!(balance, date)

    # Trigger a sync to recompute the split
    @account.sync_later if @account.split_source?

    redirect_to account_path(@account), notice: "Mortgage recalibrated to #{balance} as of #{date}."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  private

    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def ensure_loan_account
      head :not_found unless @account.accountable_type == "Loan"
    end

    def recalibration_params
      params.require(:recalibration).permit(:balance, :date)
    end
end
