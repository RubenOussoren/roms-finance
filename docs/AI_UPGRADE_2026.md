# AI Capabilities Upgrade — 2026 Architecture Plan

**Date**: March 2026
**Scope**: Multi-provider LLM support, expanded AI function coverage, AI memory, modernized chat UI

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Multi-Provider LLM Architecture](#3-multi-provider-llm-architecture)
4. [Expanded AI Function Tools](#4-expanded-ai-function-tools)
5. [AI Memory — Persistent User Context](#5-ai-memory--persistent-user-context)
6. [Chat UI Modernization](#6-chat-ui-modernization)
7. [Error Handling & Operational Concerns](#7-error-handling--operational-concerns)
8. [Implementation Phases](#8-implementation-phases)

---

## 1. Executive Summary

The AI system currently runs on OpenAI GPT-4.1 only, has 4 read-only function tools (accounts, transactions, balance sheet, income statement), no persistent memory, and a basic streaming chat UI. This document outlines the upgrade path to:

- **Multi-provider support**: OpenAI + Anthropic (Phase 1), Gemini + Ollama (Phase 4)
- **15+ function tools**: covering investments, projections, budgets, debt optimization, milestones, and more
- **AI memory**: three-layer system for persistent user context (~1,700 tokens/request overhead)
- **Modern chat UI**: message actions, accessibility, streaming improvements

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Multi-provider abstraction | **RubyLLM** (`ruby_llm` gem) | Rails-native, ActiveRecord integration, unified tool calling. One gem replaces 3+ provider SDKs. |
| Tool migration | **Wrap, don't inherit** | Keep existing `Assistant::Function` interface; adapt to RubyLLM via adapter. Avoids coupling to third-party DSL. |
| Model selection | **Admin-level setting** | Users should not pick models. Set `default_ai_model` in `Setting`. It just works. |
| Streaming | Turbo Streams + Action Cable (existing) | Already in place. Add token batching (100ms flush). |
| Cost tracking | RubyLLM built-in token counts | Per-message tracking in DB. Simple admin spend page. Defer budget enforcement. |
| RAG pipeline | **Deferred** | Financial data is structured — function tools query it via SQL more accurately than semantic search. RAG only considered later for chat history if needed. |
| Function tools | **Read-only by design** | All tools are read-only. Write operations (create transaction, set budget) are a future consideration requiring separate safety review. |

---

## 2. Current State Analysis

### 2.1 What Exists

**Provider layer** (`app/models/provider/`):
- `Provider::Openai` — sole LLM provider, uses `ruby-openai` gem
- `Provider::LlmConcept` — abstract interface with `ChatMessage`, `ChatResponse`, `ChatStreamChunk`, `ChatFunctionRequest` data structures
- `Provider::Registry` — hardcoded to `%i[openai]` for LLM concept
- `Provider::Openai::ChatConfig` — builds OpenAI-specific tool/message format
- `Provider::Openai::ChatParser` / `ChatStreamParser` — parse OpenAI-specific response JSON

**Assistant layer** (`app/models/assistant/`):
- `Assistant::Responder` — event-driven streaming handler with `emit(:output_text)` and `emit(:response)`
- `Assistant::FunctionToolCaller` — provider-agnostic function execution (already well-abstracted)
- `Assistant::Configurable` — system prompt with financial assistant identity
- `Assistant::Provided` — finds provider by model name via registry
- 4 functions: `get_accounts`, `get_transactions`, `get_balance_sheet`, `get_income_statement`

**Chat models**:
- `Chat` — user_id, title, error (JSONB), `latest_assistant_response_id` (OpenAI-specific)
- `Message` — STI (UserMessage/AssistantMessage/DeveloperMessage), status enum, `ai_model` column
- `ToolCall::Function` — persists function calls with provider IDs and results

**Background AI** (non-chat):
- `Family::AutoCategorizer` — GPT-4.1-mini, JSON schema output, max 25 transactions/batch
- `Family::AutoMerchantDetector` — GPT-4.1-mini, detects business names/URLs

### 2.2 What's Already Well-Abstracted

These pieces work provider-agnostically and can be kept:
- `ChatMessage`, `ChatResponse`, `ChatStreamChunk`, `ChatFunctionRequest` data structures
- `Assistant::FunctionToolCaller` — executes functions from any provider's requests
- `Assistant::Responder` event model (`:output_text`, `:response`)
- `with_provider_response` error handling pattern

### 2.3 What's Hardcoded to OpenAI

| Component | OpenAI-Specific Element |
|-----------|----------------------|
| `ChatConfig#tools` | `type: "function"`, `strict: true` format |
| `ChatConfig#build_input` | `type: "function_call_output"`, `call_id` format |
| `ChatParser` | `object.dig("output")`, `type: "message"`, `type: "function_call"` paths |
| `ChatStreamParser` | `response.output_text.delta`, `response.completed` event types |
| `AutoCategorizer` | `client.responses.create`, `text.format.json_schema`, `developer` role |
| `Chat` model | `latest_assistant_response_id` — OpenAI conversation chaining |
| `_chat_form.html.erb` | Hidden field hardcoded to `"gpt-4.1"` |
| `Provided#get_model_provider` | No provider preference ordering or explicit selection |

---

## 3. Multi-Provider LLM Architecture

### 3.1 Provider Comparison (2026)

#### Anthropic Claude API
- Messages API with `tools` array. Tool calls returned as `tool_use` content blocks, results sent as `tool_result`.
- `strict: true` for guaranteed schema compliance.
- Models: Claude Opus 4/4.5/4.6, Sonnet 4/4.5/4.6, Haiku 4.5.
- Ruby SDK: `anthropic-sdk-ruby` (official, v1.16.3).

#### OpenAI Responses API
- `POST /v1/responses` with `input` + `instructions`. Agentic loop by default (multiple tool calls per request).
- `previous_response_id` for conversation chaining.
- Structured output via `text.format.json_schema`.
- Models: GPT-4.1, GPT-4.1 mini, GPT-5.x series.
- Ruby SDK: `openai` (official) or `ruby-openai` (community, mature).

#### Google Gemini API (Phase 4)
- Tool schemas declared upfront. Returns `functionCall` objects; caller sends `functionResponse` back.
- Models: Gemini 2.5/3 series.
- Ruby SDK: None standalone — use through RubyLLM.

#### Ollama / Local LLMs (Phase 4)
- OpenAI-compatible REST API at `localhost:11434`.
- Tool calling support depends on the model (Llama 3.x, Mistral support it).
- `format: "json"` for JSON mode (no schema enforcement).

**Phase 1 scope**: OpenAI + Anthropic only. These two have the most mature tool-calling support and Ruby SDKs. Gemini and Ollama deferred to Phase 4 once the abstraction is proven.

### 3.2 Key Divergences for Abstraction

| Aspect | Anthropic | OpenAI | Gemini | Ollama |
|--------|-----------|--------|--------|--------|
| Tool definition | `tools[].input_schema` | `tools[].parameters` | `tools[].parameters` | OpenAI-compat |
| Tool call format | `tool_use` content block | `function_call` output item | `functionCall` part | OpenAI format |
| Tool result format | `tool_result` content block | `function_call_output` input | `functionResponse` part | OpenAI format |
| System prompt | `system` parameter | `instructions` parameter | `system_instruction` | `system` in messages |
| Conversation chain | Full message history | `previous_response_id` | Full message history | Full message history |
| Streaming events | `content_block_delta`, `message_stop` | `response.output_text.delta`, `response.completed` | Chunked SSE | OpenAI-compat |
| Schema enforcement | `strict: true` on tools | `strict: true` in JSON schema | `response_schema` | None |

### 3.3 Recommended Approach: RubyLLM

**RubyLLM** (`ruby_llm` gem, v1.3.0+) is the recommended abstraction layer. Rationale:

1. **Rails-native**: `acts_as_chat` and `acts_as_message` ActiveRecord integration.
2. **11 providers, 1170+ models**: OpenAI, Anthropic, Gemini, DeepSeek, Ollama, and more.
3. **Unified tool calling**: Define tools once; RubyLLM translates to each provider's format.
4. **Streaming**: Provider-agnostic streaming via a block that receives normalized chunk objects.
5. **Model registry**: Runtime capability queries (supports tools? vision? streaming?), context window sizes, pricing data.
6. **Token tracking**: Every response includes `input_tokens`, `output_tokens`, cost. Persisted automatically with `acts_as_message`.
7. **Minimizes dependencies**: One gem instead of 3+ separate provider SDKs. Aligns with project convention.

#### Maturity Risk Mitigation

RubyLLM is relatively new compared to `ruby-openai`. The project convention says "favor old and reliable over new and flashy." To mitigate:

- **Wrap RubyLLM behind `Provider::LlmConcept`**: Create `Provider::RubyLlm` that implements the existing `LlmConcept` interface by delegating to RubyLLM. This preserves the existing provider abstraction. If RubyLLM breaks or changes, only the adapter needs updating.
- **Keep `Assistant::Function` interface**: Do NOT inherit from `RubyLLM::Tool`. Instead, write an adapter that converts existing `Assistant::Function` definitions (with their `name`, `description`, `params_schema`, `call`, `strict_mode?` interface) to RubyLLM tool format. This keeps tool definitions owned by us, not a third-party DSL.
- **Selective `acts_as_chat` adoption**: The `Chat` and `Message` models already have STI, status enums, and tool call associations. Specify exactly which RubyLLM ActiveRecord features are used vs skipped. Do not blindly adopt `acts_as_chat` if it conflicts with existing model structure.

### 3.4 Migration Strategy

**Step 1**: Add `ruby_llm` gem. Configure providers via env vars.

**Step 2**: Create `Provider::RubyLlm` that implements `LlmConcept` by delegating to RubyLLM. This preserves the existing `Provider::Registry` pattern while gaining multi-provider support.

**Step 3**: Build an adapter layer that converts existing `Assistant::Function` subclasses to RubyLLM tool format. The execution logic and interface stay identical.

**Step 4**: Update `Chat` model to use conversation history instead of `previous_response_id`. Implement history truncation (see Section 7.2).

**Step 5**: Deprecate `Provider::Openai::ChatConfig`, `ChatParser`, `ChatStreamParser` — these are replaced by RubyLLM's normalized adapters.

### 3.5 Provider Configuration

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", Setting.openai_access_token)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", Setting.anthropic_api_key)

  # Phase 4 additions:
  # config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", Setting.gemini_api_key)
  # config.openai_api_base = ENV["OLLAMA_BASE_URL"] if ENV["OLLAMA_BASE_URL"].present?
end
```

### 3.6 Model Selection — Admin Only

Model selection is NOT user-facing. The AI model is configured by the admin in settings.

- Add `default_ai_model` to the `Setting` model (admin-level)
- The hidden field in `_chat_form.html.erb` pulls from `Setting.default_ai_model`
- The per-message `ai_model` column is populated server-side from the admin default
- No model selector dropdown in the chat UI
- No per-conversation model override

```ruby
# In Setting model
field :default_ai_model, type: :string, default: "gpt-4.1"
field :anthropic_api_key, type: :string
```

### 3.7 Structured Output Strategy

Use **tool-based schemas** as the universal structured output mechanism. Since all providers support tool calling with JSON Schema, define a "tool" whose arguments match the desired output schema. This works identically across providers without provider-specific JSON mode code.

For auto-categorization and merchant detection, convert the current OpenAI-specific JSON schema approach to tool definitions that RubyLLM normalizes across providers.

### 3.8 Cost Tracking

1. **Per-message**: Store `input_tokens`, `output_tokens`, `model_id`, `cost_cents` on each `Message` record. RubyLLM provides this data automatically.
2. **Aggregation**: Database queries for per-user, per-family, per-day rollups.
3. **Admin visibility**: Simple admin page showing total AI spend this month (one number, one query). No full dashboard yet.
4. **Budget enforcement**: Deferred. If needed later, warn the admin or disable AI chat — never silently downgrade the model, as that breaks the "it just works" principle.

---

## 4. Expanded AI Function Tools

### 4.1 Design Principles

- **All tools are read-only by design.** The AI cannot create, update, or delete any data. Write operations are a future consideration requiring a separate safety review with confirmation flows.
- **Dynamic tool loading**: Only register tools relevant to the user's account types. Don't include `get_holdings` if the user has no investment accounts. Don't include `get_debt_optimization` if no loans exist. This reduces context window usage for users with simpler setups.

### 4.2 Current Coverage Gap

The AI has 4 functions covering basic financial data. The app has 20+ major feature areas the AI cannot access:

| Feature Area | Current Access | Priority |
|--------------|---------------|----------|
| **Investments** (holdings, trades, securities) | None | Critical |
| **Projections** (account/family forecasts, PAG 2025) | None | Critical |
| **Milestones** (goals, probability, sensitivity) | None | Critical |
| **Budgets** (tracking, category allocation, variance) | None | Critical |
| **Debt Optimization** (Smith Manoeuvre, loan payoff) | None | Critical |
| Categories/Tags (hierarchy, spending breakdown) | None | High |
| Rules/Automation (transaction rules, previews) | None | High |
| Plaid/SnapTrade (connection status, sync health) | None | High |
| Merchants (spending by merchant) | None | Medium |
| Transfers (matched transfers, reconciliation) | None | Medium |
| Forecast Accuracy (MAPE, RMSE, bias) | None | Medium |
| Data Quality (missing data, inconsistencies) | None | Low |

### 4.3 New Tool: `get_financial_summary`

A high-level overview tool that provides conversational context. The AI can call this to quickly understand the user's financial situation without needing multiple tool calls.

**Output**: Net worth, total assets, total liabilities, month-over-month change, account count by type, top spending categories this month.

**Source models**: `Family`, `Account`, `Entry`

### 4.4 Tier 1 Functions (Critical)

#### `get_holdings`
Returns current investment positions with performance data.

**Output**: List of holdings with ticker, company name, quantity, price, cost basis, unrealized gain/loss, portfolio weight %, security metadata.

**Source models**: `Holding`, `Security`, `Trade`

#### `get_projections`
Returns future value projections for accounts or the entire family.

**Parameters**: `account_id` (optional — omit for family projection), `years` (default 10)

**Output**: Projected values at percentile bands (p10/p25/p50/p75/p90), monthly contributions, expected return, volatility, inflation assumptions, PAG 2025 compliance flag.

**Source models**: `ProjectionCalculator`, `FamilyProjectionCalculator`, `ProjectionAssumption`, `ProjectionStandard`

#### `get_milestones`
Returns financial goals and progress.

**Parameters**: `account_id` (optional)

**Output**: Target amount, current value, progress %, status, projected achievement date, required monthly contribution, sensitivity analysis (50%/100%/150%/200% contribution scenarios).

**Source models**: `Milestone`, `MilestoneCalculator`

#### `get_budgets`
Returns budget data with actuals vs. planned.

**Parameters**: `month` (YYYY-MM format, default current)

**Output**: Expected income, actual income, budgeted spending by category, actual spending by category, variance, surplus/deficit, % of budget spent.

**Source models**: `Budget`, `BudgetCategory`

#### `get_debt_optimization`
Returns debt strategy analysis.

**Parameters**: `strategy_id` (optional — omit for overview)

**Output**: Strategy type, status, primary mortgage details, HELOC details, simulation results (baseline vs. modified Smith Manoeuvre), months accelerated, tax benefits, net benefit.

**Source models**: `DebtOptimizationStrategy`, `CanadianSmithManoeuvrSimulator`, `LoanPayoffCalculator`

#### `get_loan_payoff`
Returns amortization and payoff analysis for a loan.

**Parameters**: `account_id`, `extra_payment` (optional)

**Output**: Current balance, interest rate, remaining amortization, monthly payment, total interest remaining. If `extra_payment` provided: months saved, interest saved, new payoff date.

**Source models**: `LoanPayoffCalculator`

### 4.5 Tier 2 Functions (High Priority)

| Function | Purpose | Key Models |
|----------|---------|-----------|
| `get_categories` | Full category tree with spending by period | `Category` |
| `get_tags` | All tags with usage counts | `Tag` |
| `get_rules` | Transaction automation rules | `Rule`, `Condition`, `Action` |
| `get_merchants` | Merchants with total spend | `Merchant`, `FamilyMerchant` |
| `get_connectivity_status` | Plaid/SnapTrade connection health | `PlaidItem`, `SnapTradeConnection` |

### 4.6 Tier 3 Functions (Medium Priority)

| Function | Purpose | Key Models |
|----------|---------|-----------|
| `get_transfers` | Matched transfers between accounts | `Transfer` |
| `get_forecast_accuracy` | How accurate past projections were | `ForecastAccuracyCalculator` |
| `get_data_quality` | Missing data, inconsistencies | `DataQualityCheckable` |
| `get_exchange_rates` | Historical FX rates | `ExchangeRate` |
| `get_tax_info` | Jurisdiction tax brackets, deductibility | `Jurisdiction` |

### 4.7 Tool Context Window Budget

With 15+ tools, tool definitions consume ~3,000-6,000 tokens. Dynamic tool loading keeps this in check:

```ruby
# Assistant::Configurable
def available_functions
  functions = [GetFinancialSummary, GetAccounts, GetTransactions, GetBalanceSheet, GetIncomeStatement]
  functions << GetHoldings if Current.family.accounts.where(accountable_type: "Investment").any?
  functions << GetBudgets if Current.family.budgets.any?
  functions << GetDebtOptimization if Current.family.accounts.where(accountable_type: "Loan").any?
  functions << SaveMemory  # always available
  # ...
  functions
end
```

---

## 5. AI Memory — Persistent User Context

The AI "learns" about users over time without RAG infrastructure. Three lightweight memory layers keep token costs minimal.

### 5.1 Layer 1: Structured User Profile (~200 tokens/request)

Add a `ai_profile` JSONB column to the `Family` model. After each conversation ends, make one cheap extraction call to pull out new facts or preferences. Merge into the existing profile (append, don't replace). Inject the full profile into the system prompt on every new chat.

```ruby
# Family#ai_profile schema
{
  "financial_goals": ["retire by 55", "pay off mortgage by 2030"],
  "risk_tolerance": "moderate",
  "household_context": "married, 2 kids, single income",
  "recurring_concerns": ["cash flow timing", "tax optimization"],
  "preferred_response_style": "concise with numbers",
  "known_accounts_context": "primary chequing at TD, RRSP at Questrade"
}
```

**Implementation:**
- `Family#update_ai_profile(conversation_messages)` — called by `Chat#after_update` when chat status transitions to inactive/closed
- One LLM call with a small/cheap model (e.g., `gpt-4.1-mini` or `claude-haiku`) using a prompt like: "Extract any new user facts, preferences, or financial goals from this conversation. Return JSON. Only include genuinely new information."
- `Family#ai_profile_prompt` — returns the profile formatted for system prompt injection
- Profile capped at 50 keys to prevent unbounded growth
- Admin can view/clear the profile from the family settings page

**Cost:** ~500 tokens per extraction (once per conversation end). ~200 tokens per-request for injection. Negligible.

### 5.2 Layer 2: Conversation Summaries (~500 tokens/request)

Add a `summary` text column to the `Chat` model. When a chat ends or reaches 10+ messages, generate a 2-3 sentence summary. On new conversations, include the last 10 summaries in the system prompt.

```
Recent conversations:
- Mar 5: Discussed high grocery spending; user wants to stay under $600/mo
- Mar 3: Reviewed investment portfolio; concerned about tech sector exposure
- Feb 28: Asked about mortgage renewal options for July 2026
```

**Implementation:**
- `Chat#generate_summary` — called when chat transitions to inactive (same hook as profile extraction, can batch both in one job)
- Summary stored as plain text, max 280 characters
- `User#recent_chat_summaries(limit: 10)` — returns formatted string for system prompt
- Summaries older than 90 days auto-expire (background job or scope)

**Cost:** ~300 tokens per summarization (once per conversation). ~500 tokens per-request for 10 summaries. Negligible.

### 5.3 Layer 3: Memory Tool — AI-Initiated Recall

Give the AI a `save_memory` function tool it can call mid-conversation when it learns something important. The AI decides what's worth remembering.

```ruby
# New function tool: Assistant::Function::SaveMemory
class Assistant::Function::SaveMemory < Assistant::Function
  def name = "save_memory"
  def description = "Save an important fact, preference, or insight about the user for future conversations. Use this when the user shares financial goals, life changes, preferences, or context that would be useful to remember."

  def params_schema
    {
      type: "object",
      properties: {
        category: {
          type: "string",
          enum: %w[financial_goal life_event preference insight account_context],
          description: "The type of memory to save"
        },
        content: {
          type: "string",
          description: "The fact or insight to remember (1-2 sentences)"
        }
      },
      required: %w[category content]
    }
  end

  def call(category:, content:)
    memory = Current.family.ai_memories.create!(
      category: category,
      content: content,
      source_chat: @chat
    )
    { saved: true, memory_id: memory.id }
  end
end
```

**Data model:**
```ruby
# Migration
create_table :ai_memories do |t|
  t.references :family, null: false, foreign_key: true
  t.references :chat, null: true, foreign_key: true  # source conversation
  t.string :category, null: false
  t.text :content, null: false
  t.datetime :expires_at           # optional TTL
  t.timestamps
end

add_index :ai_memories, [:family_id, :category]
```

**Constraints:**
- Max 50 memories per family (oldest auto-pruned when limit reached, preserving pinned memories)
- Content max 280 characters
- Duplicate detection: before saving, check if a memory with similar content already exists (exact category+content match)
- All memories loaded into system prompt on each chat (~1000 tokens for 50 short memories)
- Admin can view, pin, and delete memories from the family settings page

### 5.4 System Prompt Injection Order

1. Base instructions (existing)
2. User profile (Layer 1) — "About this user: ..."
3. Memories (Layer 3) — "Things I remember: ..."
4. Recent conversation summaries (Layer 2) — "Recent conversations: ..."
5. Tool definitions

**Total per-request token overhead:** ~1,700 tokens across all three layers. At current pricing, this is fractions of a cent per message.

### 5.5 Why Not RAG for Memory?

Memories are small (50 items x 280 chars = ~14KB). Loading all of them into the system prompt is cheaper and more reliable than maintaining a vector index, running similarity searches, and risking relevant memories being missed by embedding distance thresholds. RAG only makes sense when the corpus is too large to fit in context — 50 short memories is not that.

---

## 6. Chat UI Modernization

### 6.1 Current UI Limitations

1. **Hardcoded model** — hidden field fixed to `"gpt-4.1"`, no admin configuration
2. **No message actions** — no copy, regenerate, or feedback buttons
3. **Disabled placeholder buttons** — 4 "Coming soon" buttons add visual clutter (remove entirely)
4. **Inefficient streaming** — each token triggers a DB save + ActionCable broadcast (500 writes per response)
5. **Full redirect on submit** — `MessagesController#create` uses `redirect_to` instead of Turbo Stream append
6. **Generic errors** — same message for rate limits, network errors, and content policy violations (see Section 7)
7. **No feedback mechanism** — no thumbs up/down or quality signals
8. **Accessibility gaps** — missing `role="log"`, `aria-live`, focus management, `prefers-reduced-motion`

### 6.2 Message Actions

**On assistant messages** (hover-revealed toolbar below message):
1. **Copy** — clipboard API, Stimulus controller. No backend changes.
2. **Regenerate** — extends existing `retry_last_message!`. Only on last assistant message.
3. **Thumbs up/down** — new `message_feedbacks` table (message_id, rating, comment). Valuable for evaluating model quality when admin switches providers.

**On user messages**:
1. **Copy** — same as above

### 6.3 Streaming Improvements

1. **Token batching**: Buffer tokens in `AssistantResponseJob`, flush every 100ms instead of per-token. Reduces DB writes and broadcasts by ~10x.
2. **Streaming cursor**: CSS blinking cursor animation at the end of in-progress content. Add/remove via Turbo Stream class toggle.
3. **Optimistic UI**: Append user message client-side via Stimulus immediately on submit, before server confirms.
4. **Turbo Stream response**: Replace `redirect_to` in `MessagesController#create` with a Turbo Stream that appends the user message and shows the thinking indicator.

### 6.4 Accessibility

| Fix | Priority | Effort |
|-----|----------|--------|
| Add `role="log"` and `aria-live="polite"` to `#messages` | High | Low |
| Add `aria-live="assertive"` to thinking indicator | High | Low |
| Add `aria-label` on each message element | High | Low |
| Respect `prefers-reduced-motion` for `animate-pulse` | High | Low |
| Focus management: return focus to textarea after submit | Medium | Low |
| Keyboard shortcuts: `Ctrl+/` to focus input, `Escape` to cancel | Medium | Medium |

### 6.5 Mobile

- Safe area insets: `padding-bottom: env(safe-area-inset-bottom)` on fixed input bar
- `visualViewport` API for keyboard-aware layout
- Long-press for message actions (instead of hover)
- Existing `<details>` pattern for reasoning is good for mobile space savings

### 6.6 Content Rendering

Chat responses use well-formatted markdown. The app already has dedicated dashboard pages with charts and tables — the AI should link users to the relevant page rather than recreating dashboard widgets inline. Markdown tables are sufficient for tabular data in chat.

---

## 7. Error Handling & Operational Concerns

### 7.1 Error Handling Strategy

The current system shows generic error messages for all failure types. Each error type needs a specific response:

| Error Type | Detection | User-Facing Response | System Action |
|------------|-----------|---------------------|---------------|
| **Rate limit** | HTTP 429, `Retry-After` header | "I'm a bit busy right now. Please try again in a moment." | Retry after delay (respect `Retry-After`), max 3 retries |
| **Invalid API key** | HTTP 401/403 | "AI is temporarily unavailable. Your admin has been notified." | Log error, send admin notification |
| **Content policy** | Provider-specific refusal | "I can't help with that request. Try rephrasing your question." | Log for review, no retry |
| **Network timeout** | Connection timeout / HTTP 5xx | "Having trouble connecting. Retrying..." | Retry with exponential backoff (2s, 4s, 8s), max 3 retries |
| **Context length exceeded** | Provider error (token limit) | Transparent to user | Truncate history (keep system prompt + last N messages), retry once |
| **Provider outage** | Repeated failures | "AI is temporarily unavailable. Please try again later." | Show error, do not auto-fallback to different provider |

### 7.2 Conversation History Management

With `previous_response_id` being removed (OpenAI-specific), full conversation history is sent with each request. This needs a truncation strategy:

- **Default**: Send last 20 messages (10 user + 10 assistant turns)
- **If context limit hit**: Truncate to last 10 messages, retry
- **Tool call messages**: Always include the most recent tool call + result pair (needed for coherent follow-up)
- **System prompt + memory**: Always included, never truncated (~2,000 tokens)
- **Future consideration**: Summarize older messages instead of dropping them (use conversation summary from Layer 2)

### 7.3 Migration Path for Existing Chats

When switching from OpenAI's `previous_response_id` to full conversation history:
- Existing chats that relied on `previous_response_id` will no longer chain correctly
- Migration: set `latest_assistant_response_id` to `nil` on all existing chats
- Existing chats can still be continued — they'll just send full history instead of chaining
- No data loss, just a seamless transition

### 7.4 Rate Limiting

Per-user rate limiting to prevent runaway API costs:

- **Default**: 50 messages per user per hour
- **Configurable**: Admin sets limit in `Setting` (or disables it)
- **Implementation**: `Rack::Attack` throttle on `MessagesController#create` scoped to `Current.user.id`
- **User feedback**: "You've reached the message limit. Please try again in X minutes."

### 7.5 Fallback Strategy

If the configured provider is down:
- **Do NOT auto-fallback to a different provider.** The admin chose a specific model for a reason (cost, capability, privacy). Silently switching providers violates that decision.
- Show a clear error message and let the user retry later.
- If the admin wants redundancy, they can configure a fallback model in settings (future feature).

### 7.6 Testing Strategy for Multi-Provider

- **Unit tests**: Each `Assistant::Function` tested independently (provider-agnostic)
- **VCR cassettes**: One set per provider for the core chat flow (ask question → get response → tool call → follow-up)
- **Provider parity**: A shared test suite that runs the same 5-10 representative questions against each configured provider and asserts the response contains expected function calls (not exact text matching)
- **Privacy tests**: Every function tool has a test asserting it never returns data from another family

---

## 8. Implementation Phases

### Phase 1: Multi-Provider Foundation (2 weeks)

**Goal**: Support OpenAI + Anthropic with admin-configured model selection.

1. Add `ruby_llm` gem to Gemfile
2. Create `Provider::RubyLlm` implementing `LlmConcept` via delegation
3. Add provider API key settings: `anthropic_api_key`, `default_ai_model`
4. Build adapter layer converting `Assistant::Function` to RubyLLM tool format
5. Configure `default_ai_model` in admin settings (replace hidden hardcoded field)
6. Update `Provider::Registry` to support multiple LLM providers
7. Remove `latest_assistant_response_id` dependency — use conversation history with truncation
8. Update auto-categorizer and merchant detector to use RubyLLM
9. Implement error handling (Section 7.1)
10. Implement rate limiting (Section 7.4)

**Tests**: Update existing VCR cassettes for OpenAI, add cassettes for Anthropic. Privacy tests for family scoping.

### Phase 2: Expanded Function Tools (2-3 weeks)

**Goal**: AI can answer questions about all major financial features.

1. Implement `get_financial_summary` overview tool
2. Implement Tier 1 functions: `get_holdings`, `get_projections`, `get_milestones`, `get_budgets`, `get_debt_optimization`, `get_loan_payoff`
3. Implement Tier 2 functions: `get_categories`, `get_tags`, `get_rules`, `get_merchants`, `get_connectivity_status`
4. Implement dynamic tool loading based on user's account types
5. Update system prompt to describe new capabilities
6. Add function privacy tests for all new functions

**Tests**: Unit tests per function, privacy tests ensuring family scoping.

### Phase 3: Chat UI Improvements (1-2 weeks)

**Goal**: Modern chat experience with message actions and accessibility.

1. Remove "Coming soon" placeholder buttons
2. Add copy button on messages (Stimulus controller)
3. Add regenerate button on last assistant message
4. Add thumbs up/down feedback (new `message_feedbacks` table)
5. Implement token batching in streaming (100ms flush)
6. Replace redirect with Turbo Stream in `MessagesController#create`
7. Add streaming cursor CSS animation
8. Accessibility fixes (role, aria-live, focus management, reduced motion)
9. Mobile safe area insets and keyboard handling

**Tests**: System tests for message actions, streaming behavior.

### Phase 4: Additional Providers + Cost Tracking (1-2 weeks)

**Goal**: Gemini and Ollama support, operational cost visibility.

1. Add Gemini provider support via RubyLLM
2. Add Ollama provider support via RubyLLM
3. Add `gemini_api_key`, `ollama_base_url` to admin settings
4. Add token count columns to `messages` table
5. Store cost per message using RubyLLM pricing data
6. Create simple admin page showing total AI spend this month

**Tests**: VCR cassettes for Gemini/Ollama, cost calculation tests.

### Phase 5: AI Memory (1-2 weeks)

**Goal**: AI remembers user context across conversations.

1. Add `ai_profile` JSONB column to `Family`
2. Add `summary` text column to `Chat`
3. Create `ai_memories` table with migration
4. Implement `Family#update_ai_profile` with cheap extraction call
5. Implement `Chat#generate_summary` on conversation end
6. Create `Assistant::Function::SaveMemory` tool
7. Integrate all three layers into system prompt injection (`Assistant::Configurable`)
8. Add admin page for viewing/clearing profile and managing memories
9. Background job for profile extraction + summarization on chat close

**Tests**: Unit tests for profile extraction, summarization, SaveMemory tool. Integration test for end-to-end flow. Privacy tests for family scoping. Capacity test for 50-memory limit.

### Phase 6 (Future): RAG for Chat History

- Only if there's demonstrated need after function tools and memory layers are live
- Scope to chat history search, not structured financial data
- Financial data is structured and already queryable via function tools — RAG adds no value there

---

## Appendix A: Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `OPENAI_ACCESS_TOKEN` | OpenAI API key | At least one provider required |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key | Optional |
| `GEMINI_API_KEY` | Google Gemini API key | Optional (Phase 4) |
| `OLLAMA_BASE_URL` | Ollama server URL (e.g., `http://localhost:11434`) | Optional (Phase 4, self-hosted) |

### Self-Hosted Mode

Self-hosted users can run entirely locally with Ollama (Phase 4):
- LLM: Llama 3.x or Mistral via Ollama (tool calling support)
- No external API keys needed

### Managed Mode

Managed deployments should configure at minimum OpenAI + Anthropic. Gemini is optional. Ollama is typically not used in managed mode.

## Appendix B: Gem Dependencies

| Gem | Purpose | New? |
|-----|---------|------|
| `ruby_llm` | Multi-provider LLM abstraction | Yes |
| `ruby-openai` | OpenAI API client (already present) | No — replaced by RubyLLM |

One new gem. Aligns with Convention 1 (minimize dependencies).

## Appendix C: Key References

- [RubyLLM Documentation](https://rubyllm.com/)
- [RubyLLM Tools](https://rubyllm.com/tools/)
- [RubyLLM Rails Integration](https://rubyllm.com/rails/)
- [Anthropic Claude Tool Use](https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview)
- [OpenAI Responses API](https://platform.openai.com/docs/guides/migrate-to-responses)
- [Gemini Function Calling](https://ai.google.dev/gemini-api/docs/function-calling)
- [Ollama](https://github.com/ollama/ollama)
