class ProjectionSettingsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_account

  def update
    @assumption = ProjectionAssumption.default_for(Current.family)

    if projection_settings_params[:use_pag_defaults] == "1"
      @assumption.apply_pag_defaults!
    else
      @assumption.update!(
        expected_return: projection_settings_params[:expected_return].to_f / 100,
        volatility: projection_settings_params[:volatility].to_f / 100,
        monthly_contribution: projection_settings_params[:monthly_contribution].to_f,
        use_pag_defaults: false
      )
    end

    years = projection_settings_params[:projection_years]&.to_i || 10

    respond_to do |format|
      format.html { redirect_to account_path(@account, projection_years: years) }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@account, :projection_chart),
          UI::Account::ProjectionChart.new(account: @account, years: years, assumption: @assumption)
        )
      end
    end
  end

  private

    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def projection_settings_params
      params.permit(:expected_return, :monthly_contribution, :volatility, :projection_years, :use_pag_defaults)
    end
end
