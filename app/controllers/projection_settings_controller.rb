class ProjectionSettingsController < ApplicationController
  include ProjectionContext

  before_action :set_account

  def update
    # Create or get account-specific assumption
    @assumption = get_or_create_account_assumption

    if projection_settings_params[:use_pag_defaults] == "1"
      # Guideline defaults govern market assumptions, not the user's cash flow.
      if projection_settings_params.key?(:monthly_contribution)
        @assumption.monthly_contribution = projection_settings_params[:monthly_contribution]
      end
      @assumption.apply_pag_defaults!
      # Without a configured standard, apply_pag_defaults! does not save.
      @assumption.save! if @assumption.changed?
    else
      @assumption.update!(
        expected_return: projection_settings_params[:expected_return].to_f / 100,
        volatility: projection_settings_params[:volatility].to_f / 100,
        monthly_contribution: projection_settings_params[:monthly_contribution].to_f,
        use_pag_defaults: false
      )
    end

    redirect_to projections_path(projection_context(default_tab: "investments")), status: :see_other
  end

  def reset
    # Delete account-specific assumption to fall back to family defaults
    @account.projection_assumption&.destroy

    redirect_to projections_path(projection_context(default_tab: "investments")), status: :see_other
  end

  private

    def set_account
      @account = scoped_accounts.find(params[:account_id])
    end

    def get_or_create_account_assumption
      # If account already has custom settings, use those
      return @account.projection_assumption if @account.projection_assumption.present?

      # Otherwise, create account-specific settings based on family defaults
      ProjectionAssumption.create_for_account(@account)
    end

    def projection_settings_params
      params.permit(:expected_return, :monthly_contribution, :volatility, :projection_years, :use_pag_defaults)
    end
end
