class AiMemoryExtractionJob < ApplicationJob
  queue_as :default

  def perform(chat)
    chat.generate_summary
    Family::AiProfileExtractor.new(chat.user.family, chat).extract!
  end
end
