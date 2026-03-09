class Settings::AiUsagesController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin

  def show
    @current_month = Date.current.beginning_of_month
    assistant_messages = AssistantMessage.joins(:chat).where(chats: { user_id: Current.family.users.select(:id) })

    # Monthly totals
    monthly = assistant_messages.where(created_at: @current_month..@current_month.end_of_month)
    @monthly_cost_cents = monthly.sum(:cost_cents)
    @monthly_input_tokens = monthly.sum(:input_tokens)
    @monthly_output_tokens = monthly.sum(:output_tokens)
    @monthly_message_count = monthly.count

    # Daily breakdown (current month)
    @daily_breakdown = monthly
      .group("DATE(messages.created_at)")
      .select(
        "DATE(messages.created_at) AS day",
        "SUM(input_tokens) AS total_input_tokens",
        "SUM(output_tokens) AS total_output_tokens",
        "SUM(cost_cents) AS total_cost_cents",
        "COUNT(*) AS message_count"
      )
      .order("day DESC")

    # Per-model breakdown
    @model_breakdown = monthly
      .group(:ai_model)
      .select(
        "ai_model",
        "SUM(input_tokens) AS total_input_tokens",
        "SUM(output_tokens) AS total_output_tokens",
        "SUM(cost_cents) AS total_cost_cents",
        "COUNT(*) AS message_count"
      )
      .order("total_cost_cents DESC")
  end

  private

    def ensure_admin
      redirect_to settings_hosting_path, alert: "Not authorized" unless Current.user.admin?
    end
end
