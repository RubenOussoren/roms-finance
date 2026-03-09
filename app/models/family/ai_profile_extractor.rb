class Family::AiProfileExtractor
  def initialize(family, chat)
    @family = family
    @chat = chat
  end

  def extract!
    msgs = @chat.conversation_messages.ordered.limit(10)
    return if msgs.size < 4

    provider = Provider::Registry.for_concept(:llm).providers.first
    return unless provider

    transcript = msgs.map { |m| "#{m.role}: #{m.content}" }.join("\n")

    response = provider.chat_response(
      extraction_prompt(transcript),
      model: Setting.default_ai_model,
      instructions: "You extract structured facts from conversations. Return ONLY valid JSON, no markdown fences."
    )

    text = response.data&.messages&.first&.output_text
    return if text.blank?

    parsed = JSON.parse(text)
    return unless parsed.is_a?(Hash)

    @family.update!(ai_profile: deep_merge(@family.ai_profile || {}, parsed))
  rescue JSON::ParserError => e
    Rails.logger.error("AI profile extraction JSON parse failed: #{e.message}")
  rescue => e
    Rails.logger.error("AI profile extraction failed: #{e.message}")
  end

  private

  def extraction_prompt(transcript)
    <<~PROMPT
      Extract key facts about the user from this conversation. Return a JSON object with any of these keys (only include keys where you found relevant information):

      - "name": user's name
      - "occupation": what they do for work
      - "risk_tolerance": low/moderate/high
      - "investment_style": passive/active/mixed
      - "financial_goals": array of goal strings
      - "preferences": object of preference key-value pairs
      - "family_situation": description of household

      Conversation:
      #{transcript}
    PROMPT
  end

  def deep_merge(base, overlay)
    base.merge(overlay) do |_key, old_val, new_val|
      if old_val.is_a?(Hash) && new_val.is_a?(Hash)
        deep_merge(old_val, new_val)
      elsif old_val.is_a?(Array) && new_val.is_a?(Array)
        (old_val + new_val).uniq
      else
        new_val
      end
    end
  end
end
