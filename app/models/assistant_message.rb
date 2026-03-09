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

  def calculate_cost
    model_info = RubyLLM.models.find(ai_model)
    return 0 unless model_info

    input_cost = (input_tokens || 0) * (model_info.input_price_per_million || 0) / 1_000_000.0
    output_cost = (output_tokens || 0) * (model_info.output_price_per_million || 0) / 1_000_000.0
    ((input_cost + output_cost) * 100).round # cents
  rescue
    0
  end

  private

  def should_flush?
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - (@last_flush || 0)
    elapsed >= FLUSH_INTERVAL
  end
end
