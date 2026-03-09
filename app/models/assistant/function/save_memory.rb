class Assistant::Function::SaveMemory < Assistant::Function
  class << self
    def name
      "save_memory"
    end

    def description
      <<~INSTRUCTIONS
        Save a memory or preference about the user for future conversations.
        Use this when the user shares a preference, goal, or important fact they want you to remember.
        Categories: preference (UI/communication prefs), goal (financial targets), context (situational info), fact (personal details).
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      properties: {
        category: {
          type: "string",
          enum: AiMemory::CATEGORIES,
          description: "The category of memory to save"
        },
        content: {
          type: "string",
          description: "The memory content to save (concise, factual statement)"
        },
        expires_at: {
          type: "string",
          description: "Optional ISO8601 expiration datetime for temporary memories"
        }
      },
      required: %w[category content expires_at]
    )
  end

  def call(params = {})
    memory = family.ai_memories.create!(
      category: params["category"],
      content: params["content"],
      expires_at: params["expires_at"].present? ? Time.zone.parse(params["expires_at"]) : nil
    )

    { saved: true, id: memory.id, category: memory.category }
  rescue ActiveRecord::RecordInvalid => e
    { saved: false, error: e.message }
  end
end
