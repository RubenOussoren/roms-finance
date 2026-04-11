# Provider-agnostic auto-merchant detector using RubyLLM.
# Uses a cheap/fast model to detect business names and URLs from transaction data.
class Provider::RubyLlm::AutoMerchantDetector
  DETECTION_MODEL = "gpt-5-mini"

  def initialize(transactions: [], user_merchants: [])
    @transactions = transactions
    @user_merchants = user_merchants
  end

  def auto_detect_merchants
    chat = ::RubyLLM.chat(model: DETECTION_MODEL)

    prompt = <<~PROMPT
      #{instructions}

      Here are the user's available merchants in JSON format:

      ```json
      #{user_merchants.to_json}
      ```

      Use BOTH your knowledge AND the user-generated merchants to auto-detect the following transactions:

      ```json
      #{transactions.to_json}
      ```

      Return "null" if you are not 80%+ confident in your answer.

      Return a JSON object with a "merchants" array. Each item must have:
      - "transaction_id": the original transaction ID
      - "business_name": the detected business name, or null
      - "business_url": the URL of the business, or null

      Return ONLY valid JSON, no markdown fencing.
    PROMPT

    response = chat.ask(prompt)

    Rails.logger.info("Auto-detect merchants response tokens: #{response.tokens}")

    build_response(extract_merchants(response.content))
  end

  private
    attr_reader :transactions, :user_merchants

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def build_response(merchants)
      merchants.map do |merchant|
        AutoDetectedMerchant.new(
          transaction_id: merchant.dig("transaction_id"),
          business_name: normalize_value(merchant.dig("business_name")),
          business_url: normalize_value(merchant.dig("business_url"))
        )
      end
    end

    def normalize_value(value)
      return nil if value == "null" || value.nil?
      value
    end

    def extract_merchants(content)
      json = JSON.parse(content.gsub(/```json\n?|```/, "").strip)
      json.dig("merchants") || []
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse auto-detect merchants response: #{e.message}")
      []
    end

    def instructions
      <<~INSTRUCTIONS
        You are an assistant to a consumer personal finance app.

        Closely follow ALL the rules below while auto-detecting business names and website URLs:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Do not include the subdomain in the business_url (i.e. "amazon.com" not "www.amazon.com")
        - User merchants are considered "manual" user-generated merchants and should only be used in 100% clear cases
        - Be slightly pessimistic. We favor returning null over returning a false positive.
        - NEVER return a name or URL for generic transaction names (e.g. "Paycheck", "Laundromat", "Grocery store", "Local diner")

        Determining a value:

        - First attempt to determine the name + URL from your knowledge of global businesses
        - If no certain match, attempt to match one of the user-provided merchants
        - If no match, return null
      INSTRUCTIONS
    end
end
