class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: [ :update, :clear_cache ]

  def show
  end

  def update
    if hosting_params.key?(:require_invite_for_signup)
      Setting.require_invite_for_signup = hosting_params[:require_invite_for_signup]
    end

    if hosting_params.key?(:require_email_confirmation)
      Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
    end

    if hosting_params.key?(:market_data_provider)
      Setting.market_data_provider = hosting_params[:market_data_provider]
    end

    if hosting_params.key?(:market_data_alpha_vantage_api_key)
      Setting.market_data_alpha_vantage_api_key = hosting_params[:market_data_alpha_vantage_api_key]
    end

    if hosting_params.key?(:market_data_financial_data_api_key)
      Setting.market_data_financial_data_api_key = hosting_params[:market_data_financial_data_api_key]
    end

    if hosting_params.key?(:openai_access_token)
      Setting.openai_access_token = hosting_params[:openai_access_token]
    end

    if hosting_params.key?(:anthropic_api_key)
      Setting.anthropic_api_key = hosting_params[:anthropic_api_key]
    end

    if hosting_params.key?(:gemini_api_key)
      Setting.gemini_api_key = hosting_params[:gemini_api_key]
    end

    if hosting_params.key?(:ollama_api_base)
      Setting.ollama_api_base = hosting_params[:ollama_api_base]
    end

    if hosting_params.key?(:default_ai_model)
      Setting.default_ai_model = hosting_params[:default_ai_model]
    end

    redirect_to settings_hosting_path, notice: t(".success")
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = t(".failure")
    render :show, status: :unprocessable_entity
  end

  def clear_cache
    DataCacheClearJob.perform_later(Current.family)
    redirect_to settings_hosting_path, notice: t(".cache_cleared")
  end

  private
    def hosting_params
      params.require(:setting).permit(
        :require_invite_for_signup,
        :require_email_confirmation,
        :market_data_provider,
        :market_data_alpha_vantage_api_key,
        :market_data_financial_data_api_key,
        :openai_access_token,
        :anthropic_api_key,
        :gemini_api_key,
        :ollama_api_base,
        :default_ai_model
      )
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
