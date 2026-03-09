# Provider-agnostic auto-categorizer using RubyLLM.
# Uses a cheap/fast model to categorize transactions against user categories.
class Provider::RubyLlm::AutoCategorizer
  CATEGORIZATION_MODEL = "gpt-5.1-mini"

  def initialize(transactions: [], user_categories: [])
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    chat = ::RubyLLM.chat(model: CATEGORIZATION_MODEL)

    prompt = <<~PROMPT
      #{instructions}

      Here are the user's available categories in JSON format:

      ```json
      #{user_categories.to_json}
      ```

      Use the available categories to auto-categorize the following transactions:

      ```json
      #{transactions.to_json}
      ```

      Return a JSON object with a "categorizations" array. Each item must have:
      - "transaction_id": the original transaction ID
      - "category_name": the matched category name, or "null" if no match

      Return ONLY valid JSON, no markdown fencing.
    PROMPT

    response = chat.ask(prompt)

    Rails.logger.info("Auto-categorize response tokens: #{response.tokens}")

    build_response(extract_categorizations(response.content))
  end

  private
    attr_reader :transactions, :user_categories

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization.dig("transaction_id"),
          category_name: normalize_value(categorization.dig("category_name"))
        )
      end
    end

    def normalize_value(value)
      return nil if value == "null" || value.nil?
      value
    end

    def extract_categorizations(content)
      json = JSON.parse(content.gsub(/```json\n?|```/, "").strip)
      json.dig("categorizations") || []
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse auto-categorize response: #{e.message}")
      []
    end

    def instructions
      <<~INSTRUCTIONS
        You are an assistant to a consumer personal finance app. You will be provided a list
        of the user's transactions and a list of the user's categories. Your job is to auto-categorize
        each transaction.

        Closely follow ALL the rules below while auto-categorizing:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Attempt to match the most specific category possible (i.e. subcategory over parent category)
        - Category and transaction classifications should match (i.e. if transaction is an "expense", the category must have classification of "expense")
        - If you don't know the category, return "null"
          - You should always favor "null" over false positives
          - Be slightly pessimistic. Only match a category if you're 60%+ confident it is the correct one.
        - Each transaction has varying metadata that can be used to determine the category
          - Note: "hint" comes from 3rd party aggregators and typically represents a category name that
            may or may not match any of the user-supplied categories
      INSTRUCTIONS
    end
end
