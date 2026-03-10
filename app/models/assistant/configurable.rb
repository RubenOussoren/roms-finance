module Assistant::Configurable
  extend ActiveSupport::Concern

  CORE_FUNCTIONS = [
    Assistant::Function::GetFinancialSummary,
    Assistant::Function::GetAccounts,
    Assistant::Function::GetTransactions,
    Assistant::Function::GetBalanceSheet,
    Assistant::Function::SaveMemory
  ].freeze

  EXTENDED_GROUPS = {
    investments: {
      pattern: /invest|hold|stock|portfolio|etf|securit/i,
      functions: ->(flags) {
        fns = []
        fns << Assistant::Function::GetHoldings if flags[:has_investments]
        fns << Assistant::Function::GetProjections
        fns
      }
    },
    debt: {
      pattern: /debt|loan|mortgage|heloc|payoff|smith/i,
      functions: ->(flags) {
        fns = []
        fns << Assistant::Function::GetDebtOptimization if flags[:debt_strategies]
        fns << Assistant::Function::GetLoanPayoff if flags[:has_loans]
        fns
      }
    },
    budget: {
      pattern: /budget|spend|expense|income/i,
      functions: ->(flags) {
        fns = [ Assistant::Function::GetIncomeStatement ]
        fns << Assistant::Function::GetBudgets if flags[:budgets]
        fns << Assistant::Function::GetCategories
        fns
      }
    },
    reports: {
      pattern: /report|generate|download|export|csv|tax/i,
      functions: ->(flags) {
        fns = [
          Assistant::Function::GenerateNetWorthReport,
          Assistant::Function::GenerateSpendingReport,
          Assistant::Function::GenerateTaxReport
        ]
        fns << Assistant::Function::GenerateInvestmentReport if flags[:has_investments]
        fns
      }
    },
    metadata: {
      pattern: /tag|merchant|rule|category|automat/i,
      functions: ->(flags) {
        fns = [
          Assistant::Function::GetCategories,
          Assistant::Function::GetTags,
          Assistant::Function::GetMerchants
        ]
        fns << Assistant::Function::GetRules if flags[:rules]
        fns
      }
    },
    connections: {
      pattern: /connect|plaid|snaptrade|bank|sync|link/i,
      functions: ->(flags) {
        flags[:connections] ? [ Assistant::Function::GetConnectivityStatus ] : []
      }
    },
    goals: {
      pattern: /goal|milestone|target|progress/i,
      functions: ->(flags) {
        flags[:milestones] ? [ Assistant::Function::GetMilestones ] : []
      }
    }
  }.freeze

  class_methods do
    def config_for(chat)
      preferred_currency = Money::Currency.new(chat.user.family.currency)
      preferred_date_format = chat.user.family.date_format

      instructions = default_instructions(preferred_currency, preferred_date_format)
      instructions += memory_context(chat)

      {
        instructions: instructions,
        family: chat.user.family
      }
    end

    private
      def available_functions(family, message_content = "")
        account_types = family.accounts.distinct.pluck(:accountable_type).to_set
        feature_flags = batch_feature_checks(family).merge(
          has_investments: account_types.include?("Investment"),
          has_loans: account_types.include?("Loan")
        )

        functions = CORE_FUNCTIONS.dup

        EXTENDED_GROUPS.each do |_name, group|
          if message_content.match?(group[:pattern])
            functions.concat(group[:functions].call(feature_flags))
          end
        end

        functions.uniq
      end

      # Batches 5 existence checks into a single query using SELECT EXISTS subqueries
      def batch_feature_checks(family)
        sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL, { fid: family.id } ])
          SELECT
            EXISTS(SELECT 1 FROM milestones JOIN accounts ON accounts.id = milestones.account_id WHERE accounts.family_id = :fid) AS has_milestones,
            EXISTS(SELECT 1 FROM budgets WHERE budgets.family_id = :fid) AS has_budgets,
            EXISTS(SELECT 1 FROM debt_optimization_strategies WHERE debt_optimization_strategies.family_id = :fid) AS has_debt_strategies,
            EXISTS(SELECT 1 FROM rules WHERE rules.family_id = :fid) AS has_rules,
            (EXISTS(SELECT 1 FROM plaid_items WHERE plaid_items.family_id = :fid) OR EXISTS(SELECT 1 FROM snaptrade_connections WHERE snaptrade_connections.family_id = :fid)) AS has_connections
        SQL

        result = ActiveRecord::Base.connection.select_one(sql, "Feature Checks") || {}
        bool = ActiveModel::Type::Boolean.new

        {
          milestones: bool.cast(result["has_milestones"]),
          budgets: bool.cast(result["has_budgets"]),
          debt_strategies: bool.cast(result["has_debt_strategies"]),
          rules: bool.cast(result["has_rules"]),
          connections: bool.cast(result["has_connections"])
        }
      end

      def default_instructions(preferred_currency, preferred_date_format)
        <<~PROMPT
          ## Your identity

          You are a friendly financial assistant for an open source personal finance application called "ROMS Finance".

          ## Your purpose

          You help users understand their financial data by answering questions about their accounts, transactions, income, expenses, net worth, investments, budgets, debt strategies, projections, and more.

          ## Your capabilities

          You have access to tools that let you query the user's financial data in real-time. Use them proactively:
          - **get_financial_summary** — quick overview of net worth, assets, liabilities
          - **get_accounts** / **get_transactions** — account details and transaction history
          - **get_balance_sheet** — financial overview with trends

          You also have access to specialized tools for: investments & holdings, projections, debt strategies,
          budgets & income statements, milestones, reports (net worth, spending, tax, investment), categories,
          tags, merchants, rules, and bank connections. These tools are loaded automatically when your
          conversation is about those topics. If you need data from a specialized area, ask the user to
          be specific about what they need.

          ## Your rules

          Follow all rules below at all times.

          ### General rules

          - Provide ONLY the most important numbers and insights
          - Eliminate all unnecessary words and context
          - Ask follow-up questions to keep the conversation going. Help educate the user about their own data and entice them to ask more questions.
          - Do NOT add introductions or conclusions
          - Do NOT apologize or explain limitations

          ### Formatting rules

          - Format all responses in markdown
          - Always insert a blank line before headers (#, ##, ###) and list items (-, *, 1.) so they render correctly
          - Format all monetary values according to the user's preferred currency
          - Format dates in the user's preferred format: #{preferred_date_format}

          #### User's preferred currency

          ROMS Finance is a multi-currency app where each user has a "preferred currency" setting.

          When no currency is specified, use the user's preferred currency for formatting and displaying monetary values.

          - Symbol: #{preferred_currency.symbol}
          - ISO code: #{preferred_currency.iso_code}
          - Default precision: #{preferred_currency.default_precision}
          - Default format: #{preferred_currency.default_format}
            - Separator: #{preferred_currency.separator}
            - Delimiter: #{preferred_currency.delimiter}

          ### Rules about financial advice

          You should focus on educating the user about personal finance using their own data so they can make informed decisions.

          - Do not tell the user to buy or sell specific financial products or investments.
          - Do not make assumptions about the user's financial situation. Use the functions available to get the data you need.

          ### Function calling rules

          - Use the functions available to you to get user financial data and enhance your responses
          - For functions that require dates, use the current date as your reference point: #{Date.current}
          - If you suspect that you do not have enough data to 100% accurately answer, be transparent about it and state exactly what
            the data you're presenting represents and what context it is in (i.e. date range, account, etc.)
          - When a user asks about investments, use get_holdings. For projections, use get_projections. For budgets, use get_budgets.
          - Start with get_financial_summary if the user asks a broad question about their finances.
          - **save_memory** — save user preferences, goals, or facts for future conversations

          When a report function returns a download_path, present it as a markdown link like: [Download Report](download_path)
        PROMPT
      end

      def memory_context(chat)
        family = chat.user.family
        sections = []

        # Layer 1: AI profile
        if family.ai_profile.present? && family.ai_profile.any?
          profile_lines = family.ai_profile.map { |k, v| "- **#{k.humanize}**: #{v}" }.join("\n")
          sections << "\n\n## What I know about you\n\n#{profile_lines}"
        end

        # Layer 2: Saved memories
        memories = family.ai_memories.active.ordered.limit(50)
        if memories.any?
          memory_lines = memories.map { |m| "- [#{m.category}] #{m.content}" }.join("\n")
          sections << "\n\n## Your saved preferences and facts\n\n#{memory_lines}"
        end

        # Layer 3: Recent conversation summaries
        recent_chats = chat.user.chats.where.not(summary: nil).order(updated_at: :desc).limit(10)
        if recent_chats.any?
          summary_lines = recent_chats.map { |c| "- #{c.title}: #{c.summary}" }.join("\n")
          sections << "\n\n## Recent conversation context\n\n#{summary_lines}"
        end

        sections.join
      end
  end
end
