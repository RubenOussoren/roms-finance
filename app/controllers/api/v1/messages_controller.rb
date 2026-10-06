# frozen_string_literal: true

class Api::V1::MessagesController < Api::V1::BaseController
  before_action :require_ai_enabled
  before_action :ensure_write_scope, only: [ :create, :retry ]
  before_action :set_chat

  def create
    @message = @chat.messages.build(
      content: message_params[:content],
      type: "UserMessage",
      ai_model: message_params[:model] || "gpt-5-mini"
    )

    if @message.save
      render :show, status: :created
    else
      render json: { error: "Failed to create message", details: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def retry
    attempt = @chat.retry_last_message!(message_id: params[:message_id],
      recover_interrupted: ActiveModel::Type::Boolean.new.cast(params[:recover_interrupted]))
    render json: {
      message: "Retry initiated",
      attempt_id: attempt.id,
      message_id: attempt.id,
      origin_user_message_id: attempt.origin_user_message_id,
      status: attempt.status
    }, status: :accepted
  rescue Chat::RetryUnavailable => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Message not found" }, status: :not_found
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_chat
      @chat = Current.user.chats.find(params[:chat_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Chat not found" }, status: :not_found
    end

    def message_params
      params.permit(:content, :model)
    end
end
