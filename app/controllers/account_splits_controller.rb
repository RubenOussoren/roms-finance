class AccountSplitsController < ApplicationController
  before_action :set_account
  before_action :ensure_loan_account

  def new
  end

  def create
    @heloc = @account.create_balance_split!(**split_params.to_h.symbolize_keys)
    redirect_to account_path(@account), notice: "Split created. HELOC account '#{@heloc.name}' will now track separately."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def destroy
    @account.remove_balance_split!
    redirect_to account_path(@account), notice: "Split removed. Balances merged back into this account."
  end

  private

    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def ensure_loan_account
      head :not_found unless @account.accountable_type == "Loan"
    end

    def split_params
      params.require(:split).permit(
        :heloc_name, :heloc_balance, :origination_date,
        :interest_rate, :rate_type, :term_months
      )
    end
end
