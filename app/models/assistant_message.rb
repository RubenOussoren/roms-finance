class AssistantMessage < Message
  FLUSH_INTERVAL = 0.1 # seconds

  validates :ai_model, presence: true

  def role
    "assistant"
  end

  def start_streaming!
    @buffer = +""
    @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def append_text!(text)
    @buffer ||= +""
    @buffer << text
    flush_buffer! if should_flush?
  end

  def flush_buffer!
    return if @buffer.blank?
    self.content = (content || "") + @buffer
    save!
    @buffer = +""
    @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  private

  def should_flush?
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - (@last_flush || 0)
    elapsed >= FLUSH_INTERVAL
  end
end
