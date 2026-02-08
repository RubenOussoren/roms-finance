class DebtRepaymentSettingsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_account

  def update
    @assumption = get_or_create_account_assumption

    @assumption.update!(
      extra_monthly_payment: debt_settings_params[:extra_monthly_payment].to_f,
      target_payoff_date: debt_settings_params[:target_payoff_date].presence
    )

    update_loan_lump_sum if @account.accountable_type == "Loan"

    respond_to do |format|
      format.html { redirect_to projections_path(tab: "debt") }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            dom_id(@account, :debt_payoff_chart),
            UI::Projections::DebtPayoffChart.new(account: @account, extra_payment: effective_extra_payment)
          ),
          turbo_stream.replace(
            dom_id(@account, :debt_settings),
            UI::Projections::DebtSettingsInline.new(account: @account)
          )
        ]
      end
    end
  end

  def reset
    @account.projection_assumption&.update!(extra_monthly_payment: 0, target_payoff_date: nil)

    if @account.accountable_type == "Loan"
      @account.accountable.update!(annual_lump_sum_amount: nil, annual_lump_sum_month: nil)
    end

    respond_to do |format|
      format.html { redirect_to projections_path(tab: "debt") }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            dom_id(@account, :debt_payoff_chart),
            UI::Projections::DebtPayoffChart.new(account: @account, extra_payment: 0)
          ),
          turbo_stream.replace(
            dom_id(@account, :debt_settings),
            UI::Projections::DebtSettingsInline.new(account: @account)
          )
        ]
      end
    end
  end

  private

    def set_account
      @account = scoped_accounts.find(params[:account_id])
    end

    def get_or_create_account_assumption
      return @account.projection_assumption if @account.projection_assumption.present?

      ProjectionAssumption.create_for_account(@account)
    end

    def effective_extra_payment
      @account.projection_assumption&.effective_extra_payment.to_d
    end

    def debt_settings_params
      params.permit(:extra_monthly_payment, :target_payoff_date, :annual_lump_sum_amount, :annual_lump_sum_month)
    end

    def update_loan_lump_sum
      loan = @account.accountable
      attrs = {}
      attrs[:annual_lump_sum_amount] = debt_settings_params[:annual_lump_sum_amount].to_f if debt_settings_params.key?(:annual_lump_sum_amount)
      attrs[:annual_lump_sum_month] = debt_settings_params[:annual_lump_sum_month].presence&.to_i if debt_settings_params.key?(:annual_lump_sum_month)
      loan.update!(attrs) if attrs.present?
    end
end
