module Provider::LlmConcept
  extend ActiveSupport::Concern

  AutoCategorization = Data.define(:transaction_id, :category_name)

  def auto_categorize(transactions)
    raise NotImplementedError, "Subclasses must implement #auto_categorize"
  end

  AutoDetectedMerchant = Data.define(:transaction_id, :business_name, :business_url)

  def auto_detect_merchants(transactions)
    raise NotImplementedError, "Subclasses must implement #auto_detect_merchants"
  end

  ChatMessage = Data.define(:id, :output_text)
  ChatStreamChunk = Data.define(:type, :data)
  ChatResponse = Data.define(:id, :model, :messages, :function_requests, :tool_calls_log) do
    def initialize(id:, model:, messages:, function_requests:, tool_calls_log: [])
      super
    end
  end
  ChatFunctionRequest = Data.define(:id, :call_id, :function_name, :function_args)

  def chat_response(prompt, model:, instructions: nil, function_instances: [], messages: [], streamer: nil)
    raise NotImplementedError, "Subclasses must implement #chat_response"
  end
end
