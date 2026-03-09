class Settings::AiMemoriesController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin

  def show
    @ai_profile = Current.family.ai_profile || {}
    @ai_memories = Current.family.ai_memories.ordered
  end

  def destroy
    memory = Current.family.ai_memories.find(params[:id])
    memory.destroy!
    redirect_to settings_ai_memory_path, notice: "Memory deleted"
  end

  def clear
    Current.family.ai_memories.destroy_all
    Current.family.update!(ai_profile: {})
    redirect_to settings_ai_memory_path, notice: "All AI memories cleared"
  end

  private

  def ensure_admin
    redirect_to settings_hosting_path, alert: "Not authorized" unless Current.user.admin?
  end
end
