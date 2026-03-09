module Assistant::Configurable
  extend ActiveSupport::Concern

  class_methods do
    def config_for(chat)
      preferred_currency = Money::Currency.new(chat.user.family.currency)
      preferred_date_format = chat.user.family.date_format

      instructions = default_instructions(preferred_currency, preferred_date_format)
      instructions += memory_context(chat)

      {
        instructions: instructions,
        functions: available_functions(chat.user.family)
      }
    end

    private
      def available_functions(family)
        functions = [
          Assistant::Function::GetFinancialSummary,
          Assistant::Function::GetAccounts,
          Assistant::Function::GetTransactions,
          Assistant::Function::GetBalanceSheet,
          Assistant::Function::GetIncomeStatement
        ]

        # Investment tools — only if user has investment accounts
        if family.accounts.where(accountable_type: "Investment").exists?
          functions << Assistant::Function::GetHoldings
        end

        # Projections — always available
        functions << Assistant::Function::GetProjections

        # Milestones — only if any milestones exist
        if Milestone.joins(:account).where(accounts: { family_id: family.id }).exists?
          functions << Assistant::Function::GetMilestones
        end

        # Budget — only if budgets have been set up
        if family.budgets.exists?
          functions << Assistant::Function::GetBudgets
        end

        # Debt optimization — only if strategies exist
        if family.debt_optimization_strategies.exists?
          functions << Assistant::Function::GetDebtOptimization
        end

        # Loan payoff — only if loan accounts exist
        if family.accounts.where(accountable_type: "Loan").exists?
          functions << Assistant::Function::GetLoanPayoff
        end

        # Always available utility tools
        functions.push(
          Assistant::Function::GetCategories,
          Assistant::Function::GetTags,
          Assistant::Function::GetMerchants,
          Assistant::Function::SaveMemory
        )

        # Rules — only if rules exist
        if family.rules.exists?
          functions << Assistant::Function::GetRules
        end

        # Connectivity status — only if connected accounts exist
        if PlaidItem.where(family: family).exists? || SnapTradeConnection.where(family: family).exists?
          functions << Assistant::Function::GetConnectivityStatus
        end

        functions
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
          - **get_balance_sheet** / **get_income_statement** — financial statements with trends
          - **get_holdings** — investment portfolio with performance data
          - **get_projections** — future value projections with confidence bands
          - **get_milestones** — financial goals and progress
          - **get_budgets** — budget vs actual spending by category
          - **get_debt_optimization** — Smith Manoeuvre and debt strategy analysis
          - **get_loan_payoff** — loan amortization and extra payment scenarios
          - **get_categories** / **get_tags** / **get_merchants** — spending breakdowns
          - **get_rules** — transaction automation rules
          - **get_connectivity_status** — bank/brokerage connection health

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
