module Invitable
  extend ActiveSupport::Concern

  included do
    helper_method :invite_code_required?, :valid_invite_code_in_params?
  end

  private
    def valid_invite_code_in_params?
      token = params[:invite] || params.dig(:user, :invite_code) || params[:invite_code]
      token.present? && InviteCode.exists?(token: token.downcase)
    end

    def invite_code_required?
      return false if @invitation.present?
      if self_hosted?
        Setting.require_invite_for_signup
      else
        ENV["REQUIRE_INVITE_CODE"] == "true" || ENV["INVITE_ONLY"] == "true"
      end
    end

    def self_hosted?
      Rails.application.config.app_mode.self_hosted?
    end
end
