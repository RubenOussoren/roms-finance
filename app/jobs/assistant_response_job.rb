class AssistantResponseJob < ApplicationJob
  queue_as :high_priority

  def perform(message)
    # Pre-rollout jobs contain UserMessage records. Do not reinterpret them as new intent.
    return unless message.is_a?(AssistantMessage)
    message.request_response
  end
end
