class MessageFeedbacksController < ApplicationController
  guard_feature unless: -> { Current.user.ai_enabled? }

  before_action :set_message

  def create
    existing = @message.feedback
    if existing && existing.user == Current.user
      if existing.rating == feedback_params[:rating]
        existing.destroy!
      else
        existing.update!(rating: feedback_params[:rating])
      end
    else
      @message.create_feedback!(user: Current.user, rating: feedback_params[:rating])
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@message, :feedback), partial: "message_feedbacks/buttons", locals: { message: @message.reload }) }
      format.html { redirect_to chat_path(@message.chat) }
    end
  end

  private

  def set_message
    @message = Current.user.chats.joins(:messages).find_by!(messages: { id: params[:message_id] }).messages.find(params[:message_id])
  end

  def feedback_params
    params.require(:message_feedback).permit(:rating)
  end
end
