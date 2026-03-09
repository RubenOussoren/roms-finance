# AI Capabilities Upgrade — 2026 Research & Architecture Plan

**Date**: March 2026
**Scope**: Multi-provider LLM support, RAG pipeline with pgvector, expanded AI function coverage, modernized chat UI

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Multi-Provider LLM Architecture](#3-multi-provider-llm-architecture)
4. [RAG Pipeline with pgvector](#4-rag-pipeline-with-pgvector)
5. [Expanded AI Function Tools](#5-expanded-ai-function-tools)
6. [Chat UI Modernization](#6-chat-ui-modernization)
7. [Implementation Phases](#7-implementation-phases)

---

## 1. Executive Summary

The AI system currently runs on OpenAI GPT-4.1 only, has 4 read-only function tools (accounts, transactions, balance sheet, income statement), no RAG, and a basic streaming chat UI. This document outlines the upgrade path to:

- **4 provider families**: OpenAI, Anthropic Claude, Google Gemini, Local LLMs (Ollama)
- **RAG pipeline**: pgvector + `neighbor` gem for semantic search over financial data
- **15+ function tools**: covering investments, projections, budgets, debt optimization, milestones, and more
- **Modern chat UI**: model selector, message actions, rich financial content rendering, accessibility

### Key Technology Recommendations

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Multi-provider abstraction | **RubyLLM** (`ruby_llm` gem) | Rails-native, ActiveRecord integration, 11 providers, unified tool calling. One gem replaces 3+ provider SDKs. |
| Vector database | **pgvector 0.8+** via `neighbor` gem | No new infrastructure. Works with existing PostgreSQL. HNSW indexing. |
| Embedding model (managed) | OpenAI `text-embedding-3-small` at 1024 dims | Already using ruby-openai. Negligible cost (<$0.01/user/year). |
| Embedding model (self-hosted) | BGE-M3 via Ollama | Apache 2.0 licensed, 1024 dims, no external API dependency. |
| Streaming | Turbo Streams + Action Cable (existing) | Already in place. Add token batching (100ms flush). Consider AnyCable at scale. |
| Cost tracking | RubyLLM built-in token counts + `RubyLLM::Monitoring` engine | Per-message tracking in DB. Aggregation dashboards when needed. |

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
- New: **Programmatic Tool Calling** (code-based multi-tool), **Tool Search** (runtime tool surface), **Tool Runner** SDK (auto-manages tool loop).
- Models: Claude Opus 4/4.5/4.6, Sonnet 4/4.5/4.6, Haiku 4.5.
- Ruby SDK: `anthropic-sdk-ruby` (official, v1.16.3).

#### OpenAI Responses API
- `POST /v1/responses` with `input` + `instructions`. Agentic loop by default (multiple tool calls per request).
- `previous_response_id` for conversation chaining.
- Structured output via `text.format.json_schema`.
- New: WebSocket mode, server-side compaction, **Open Responses** standard (backed by Hugging Face).
- Models: GPT-4.1, GPT-4.1 mini, GPT-5.x series.
- Ruby SDK: `openai` (official) or `ruby-openai` (community, mature).

#### Google Gemini API
- Tool schemas declared upfront. Returns `functionCall` objects; caller sends `functionResponse` back.
- Native structured output via `response_schema`.
- New: Streaming function call arguments, **Interactions API** (beta).
- Models: Gemini 2.5/3 series.
- Ruby SDK: None standalone — use through RubyLLM or Langchainrb.

#### Ollama / Local LLMs
- OpenAI-compatible REST API at `localhost:11434`.
- GGUF format. Tool calling support depends on the model (Llama 3.x, Mistral support it).
- `format: "json"` for JSON mode (no schema enforcement).
- ~41 tok/s at 4 parallel requests; ~95 tok/s for 8B models on RTX 4090.
- Version: Ollama 0.15.5, llama.cpp b7931.

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
3. **Unified tool calling**: Define tools once with a Ruby DSL; RubyLLM translates to each provider's format.
4. **Streaming**: Provider-agnostic streaming via a block that receives normalized chunk objects.
5. **Model registry**: Runtime capability queries (supports tools? vision? streaming?), context window sizes, pricing data.
6. **Three-level configuration**: Global defaults → isolated contexts (multi-tenancy) → instance overrides.
7. **Token tracking**: Every response includes `input_tokens`, `output_tokens`, cost. Persisted automatically with `acts_as_message`.
8. **Minimizes dependencies**: One gem instead of 3+ separate provider SDKs. Aligns with project convention.

#### RubyLLM Tool Definition Pattern

```ruby
class GetAccounts < RubyLLM::Tool
  description "Retrieves all accounts with current balances and historical balance data"

  param :account_type, desc: "Filter by account type", required: false

  def execute(account_type: nil)
    accounts = Current.family.accounts.accessible
    accounts = accounts.where(accountable_type: account_type) if account_type
    accounts.map { |a| format_account(a) }
  end
end
```

This replaces the current `Assistant::Function` base class. The schema is auto-generated from the `param` declarations and works identically across all providers.

#### RubyLLM Streaming Pattern

```ruby
chat.ask(user_message.content) do |chunk|
  Turbo::StreamsChannel.broadcast_append_to(
    @chat, target: "messages", html: chunk.content
  )
end
```

### 3.4 Migration Strategy

Since the app already has a well-structured provider layer, the migration is incremental:

**Step 1**: Add `ruby_llm` gem. Configure providers via env vars.

**Step 2**: Create `Provider::RubyLlm` that implements `LlmConcept` by delegating to RubyLLM. This preserves the existing `Provider::Registry` pattern while gaining multi-provider support.

**Step 3**: Migrate `Assistant::Function` subclasses to `RubyLLM::Tool` subclasses. The execution logic stays identical.

**Step 4**: Update `Chat` model to use RubyLLM's `acts_as_chat` pattern for conversation history management, replacing `previous_response_id`.

**Step 5**: Deprecate `Provider::Openai::ChatConfig`, `ChatParser`, `ChatStreamParser` — these are replaced by RubyLLM's normalized adapters.

### 3.5 Provider Configuration

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN", Setting.openai_access_token)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", Setting.anthropic_api_key)
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", Setting.gemini_api_key)

  # Ollama (self-hosted)
  if ENV["OLLAMA_BASE_URL"].present?
    config.openai_api_base = ENV["OLLAMA_BASE_URL"]  # Ollama uses OpenAI-compat endpoint
  end
end
```

### 3.6 Model Selection Data Model

Add to the `settings` or `families` table:

```ruby
# New columns on families table
add_column :families, :default_ai_model, :string, default: "claude-sonnet-4-6"
add_column :families, :ai_provider_config, :jsonb, default: {}
```

The per-message `ai_model` column already exists. The family-level default gives admins control while users can override per-conversation.

### 3.7 Structured Output Strategy

Use **tool-based schemas** as the universal structured output mechanism. Since all four providers support tool calling with JSON Schema, define a "tool" whose arguments match the desired output schema. This works identically across providers without provider-specific JSON mode code.

For auto-categorization and merchant detection, convert the current OpenAI-specific JSON schema approach to tool definitions that RubyLLM normalizes across providers.

### 3.8 Cost Tracking

1. **Per-message**: Store `input_tokens`, `output_tokens`, `model_id`, `cost_cents` on each `Message` record. RubyLLM's `acts_as_message` provides this automatically.
2. **Aggregation**: Database queries for per-user, per-family, per-day rollups.
3. **Budget enforcement**: Before each request, check accumulated cost against family budget. Reject or downgrade model if over budget.
4. **Dashboard**: Add `RubyLLM::Monitoring` Rails engine when operational visibility is needed.

---

## 4. RAG Pipeline with pgvector

### 4.1 Technology Stack

| Component | Choice | Version |
|-----------|--------|---------|
| Vector extension | pgvector | 0.8.2 |
| Rails integration | `neighbor` gem | 0.6.0 |
| Embedding model (managed) | OpenAI `text-embedding-3-small` | 1024 dimensions |
| Embedding model (self-hosted) | BGE-M3 via Ollama | 1024 dimensions |
| Index type | HNSW | `m=16`, `ef_construction=128` |
| Distance function | Cosine (`vector_cosine_ops`) | — |
| Hybrid search | pgvector + PostgreSQL `tsvector` | Built-in, no extra extensions |

### 4.2 Schema Design

Single polymorphic `embeddings` table:

```ruby
class CreateEmbeddings < ActiveRecord::Migration[7.2]
  def change
    enable_extension "vector"

    create_table :embeddings, id: :uuid do |t|
      t.references :embeddable, polymorphic: true, type: :uuid, null: false
      t.references :family, type: :uuid, null: false
      t.vector :embedding, limit: 1024
      t.string :content_hash, null: false     # SHA256 of source text for staleness detection
      t.text :chunk_text, null: false          # the text that was embedded
      t.string :chunk_type                     # "transaction", "account", "category", "goal", etc.
      t.jsonb :metadata, default: {}           # structured data for pre-filtering
      t.timestamps
    end

    add_index :embeddings, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    add_index :embeddings, [:embeddable_type, :embeddable_id]
    add_index :embeddings, :family_id
    add_index :embeddings, :content_hash
    add_index :embeddings, "to_tsvector('english', chunk_text)", using: :gin
  end
end
```

**Design rationale**:
- **Polymorphic**: One table for Transaction, Account, Category, Goal, Message embeddings. Avoids schema sprawl.
- **`family_id` denormalization**: Pre-filter queries to one family before vector search. pgvector 0.8+ `hnsw.iterative_scan` combines WHERE clauses with HNSW efficiently.
- **`content_hash`**: SHA256 of source text. Skip re-embedding when hash matches. Cheap staleness detection.
- **`chunk_text`**: Stores the exact embedded text. Essential for debugging, context display, and prompt injection.
- **`metadata` JSONB**: Structured fields (amount, date, category, account_type) for two-stage retrieval.
- **GIN index on tsvector**: Enables hybrid keyword + vector search without additional extensions.

### 4.3 What to Embed

Financial data is naturally structured and short — each record is already a complete semantic unit. No complex chunking strategies needed.

**Transactions** (highest volume, most valuable):
```
Transaction: $45.23 at Costco Wholesale on 2026-01-15.
Category: Groceries. Account: Joint Chequing.
Tags: bulk-shopping, household. Note: Monthly Costco run.
```
One chunk per transaction. Under 100 tokens each.

Metadata: `{ amount: 45.23, currency: "CAD", date: "2026-01-15", category: "Groceries", account_id: "uuid", merchant: "Costco Wholesale" }`

**Accounts**:
```
Account: Joint Chequing (TD Canada Trust). Type: Checking.
Balance: $4,523.67. Notes: Primary household spending account.
```
One chunk per account. Re-embed when name, notes, or type changes.

**Categories and Tags** (single taxonomy chunk per family):
```
Family categories: Groceries, Dining Out, Transportation, Mortgage, Insurance, Subscriptions.
Family tags: tax-deductible, business-expense, recurring, household, discretionary.
```

**Goals/Milestones**:
```
Goal: Emergency Fund. Target: $25,000 by 2026-12-31.
Current: $18,400. Notes: Building to 6 months of expenses.
```

**Chat History** (assistant messages only — they contain synthesized financial analysis):
```
Assistant: Your grocery spending averaged $423/month this quarter, up 12% from last quarter.
The largest increase was at Costco ($189/month, up from $145).
```

### 4.4 Embeddable Concern

```ruby
# app/models/concerns/embeddable.rb
module Embeddable
  extend ActiveSupport::Concern

  included do
    has_one :embedding, as: :embeddable, dependent: :destroy
    after_commit :enqueue_embedding, on: [:create, :update]
  end

  def enqueue_embedding
    EmbedRecordJob.perform_later(self.class.name, self.id)
  end

  # Subclasses implement:
  # def embedding_text — the text to embed
  # def embedding_metadata — JSONB metadata for pre-filtering
end
```

The job computes SHA256 of `embedding_text`, checks `content_hash`, calls the embedding API if changed, and upserts the record.

### 4.5 Query Patterns

**Basic semantic search**:
```ruby
query_embedding = embedding_provider.embed(user_question)

relevant = Embedding
  .where(family: Current.family)
  .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
  .limit(10)
```

**Hybrid search (vector + keyword)**:
```ruby
Embedding
  .where(family: Current.family)
  .where("to_tsvector('english', chunk_text) @@ plainto_tsquery('english', ?)", user_query)
  .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
  .limit(10)
```

**Structured pre-filtering** (two-stage retrieval):
```ruby
# "What did I spend on groceries last month?"
Embedding
  .where(family: Current.family)
  .where(chunk_type: "transaction")
  .where("metadata->>'category' = ?", "Groceries")
  .where("(metadata->>'date')::date >= ?", 1.month.ago.to_date)
  .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
  .limit(10)
```

### 4.6 RAG Integration with Chat

Extend `Assistant::Configurable` to inject RAG context into the system prompt:

```ruby
def instructions
  base = system_prompt
  if rag_context.present?
    base += "\n\nRelevant context from the user's financial data:\n#{rag_context}"
  end
  base
end

def rag_context
  return nil unless user_message_content.present?

  query_embedding = embed(user_message_content)
  chunks = Embedding
    .where(family: Current.family)
    .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
    .limit(8)

  chunks.map.with_index { |c, i| "[#{i + 1}] #{c.chunk_text}" }.join("\n\n")
end
```

RAG complements function tools — it provides background context while tools provide on-demand structured data retrieval.

### 4.7 Cost Estimate

| Data Type | Typical Volume | Tokens/Record | Annual Cost (text-embedding-3-small) |
|-----------|---------------|---------------|--------------------------------------|
| Transactions | 5,000/year | ~50 | $0.005 |
| Accounts | 20 | ~60 | <$0.001 |
| Categories/Tags | 1 chunk | ~100 | <$0.001 |
| Goals | 5-10 | ~50 | <$0.001 |
| **Total per user** | | | **< $0.01/year** |

Re-embedding on data changes roughly doubles this. Cost is negligible.

### 4.8 Self-Hosted Compatibility

pgvector is available in the official PostgreSQL Docker images (`pgvector/pgvector:pg17`). The `neighbor` gem is the only Ruby dependency. For embedding generation, self-hosted users run BGE-M3 via Ollama — same infrastructure as their local LLM.

---

## 5. Expanded AI Function Tools

### 5.1 Current Coverage Gap

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

### 5.2 Tier 1 Functions (Critical)

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

### 5.3 Tier 2 Functions (High Priority)

| Function | Purpose | Key Models |
|----------|---------|-----------|
| `get_categories` | Full category tree with spending by period | `Category` |
| `get_tags` | All tags with usage counts | `Tag` |
| `get_rules` | Transaction automation rules | `Rule`, `Condition`, `Action` |
| `get_merchants` | Merchants with total spend | `Merchant`, `FamilyMerchant` |
| `get_connectivity_status` | Plaid/SnapTrade connection health | `PlaidItem`, `SnapTradeConnection` |

### 5.4 Tier 3 Functions (Medium Priority)

| Function | Purpose | Key Models |
|----------|---------|-----------|
| `get_transfers` | Matched transfers between accounts | `Transfer` |
| `get_forecast_accuracy` | How accurate past projections were | `ForecastAccuracyCalculator` |
| `get_data_quality` | Missing data, inconsistencies | `DataQualityCheckable` |
| `get_exchange_rates` | Historical FX rates | `ExchangeRate` |
| `get_tax_info` | Jurisdiction tax brackets, deductibility | `Jurisdiction` |

---

## 6. Chat UI Modernization

### 6.1 Current UI Limitations

1. **Hardcoded model** — hidden field fixed to `"gpt-4.1"`, no selector
2. **No message actions** — no copy, regenerate, feedback, or edit buttons
3. **Plain markdown only** — no syntax highlighting, no styled tables, no financial visualizations
4. **No artifact system** — function results are consumed by the LLM and re-expressed as prose instead of rendered natively
5. **Disabled placeholder buttons** — 4 "Coming soon" buttons add visual clutter
6. **Inefficient streaming** — each token triggers a DB save + ActionCable broadcast (500 writes per response)
7. **Full redirect on submit** — `MessagesController#create` uses `redirect_to` instead of Turbo Stream append
8. **No conversation branching** — linear messages only, no edit/fork capability
9. **Generic errors** — same message for rate limits, network errors, and content policy violations
10. **No feedback mechanism** — no thumbs up/down or quality signals
11. **No conversation search** — chats listed by date only
12. **Accessibility gaps** — missing `role="log"`, `aria-live`, focus management, `prefers-reduced-motion`

### 6.2 Model Selector

Replace the hidden `ai_model` field with a dropdown in the chat input area.

**Design**:
- Use existing `DS::Menu` component
- Group models by provider (OpenAI, Claude, Gemini, Local)
- Show capability badges (tools, vision, streaming)
- Show cost indicator ($, $$, $$$)
- Persist selection on the `Message` record (existing `ai_model` column)
- Family-level default from settings

**Data source**: RubyLLM's model registry provides model metadata (name, capabilities, pricing, context window) across all providers.

### 6.3 Message Actions

**On assistant messages** (hover-revealed toolbar below message):
1. **Copy** — clipboard API, Stimulus controller. No backend changes.
2. **Regenerate** — extends existing `retry_last_message!`. Only on last assistant message.
3. **Thumbs up/down** — new `message_feedbacks` table (message_id, rating, comment).

**On user messages**:
1. **Copy** — same as above
2. **Edit + regenerate** — opens editable textarea, on save creates new messages from that point. Requires `parent_message_id` column (Phase 3).

### 6.4 Rich Financial Content

Instead of all output as markdown prose, define **content blocks** the assistant can emit:

| Block Type | Rendering | Source |
|------------|-----------|--------|
| `table` | Interactive, sortable table using app design system | Function tool structured results |
| `chart` | D3.js visualization (line, bar, pie) using existing chart components | Balance/spending/projection data |
| `summary_card` | Styled card matching dashboard widgets | Account/net worth summaries |
| `code` | Syntax-highlighted with copy button | Any code in responses |

**Implementation**: Function tools return structured JSON alongside the LLM's text. A Stimulus controller in the message partial detects `data-content-block` attributes and hydrates them with interactive behavior.

### 6.5 Streaming Improvements

1. **Token batching**: Buffer tokens in `AssistantResponseJob`, flush every 100ms instead of per-token. Reduces DB writes and broadcasts by ~10x.
2. **Streaming cursor**: CSS blinking cursor animation at the end of in-progress content. Add/remove via Turbo Stream class toggle.
3. **Optimistic UI**: Append user message client-side via Stimulus immediately on submit, before server confirms.
4. **Turbo Stream response**: Replace `redirect_to` in `MessagesController#create` with a Turbo Stream that appends the user message and shows the thinking indicator.

### 6.6 Accessibility

| Fix | Priority | Effort |
|-----|----------|--------|
| Add `role="log"` and `aria-live="polite"` to `#messages` | High | Low |
| Add `aria-live="assertive"` to thinking indicator | High | Low |
| Add `aria-label` on each message element | High | Low |
| Respect `prefers-reduced-motion` for `animate-pulse` | High | Low |
| Focus management: return focus to textarea after submit | Medium | Low |
| Keyboard shortcuts: `Ctrl+/` to focus input, `Escape` to cancel | Medium | Medium |

### 6.7 Mobile

- Safe area insets: `padding-bottom: env(safe-area-inset-bottom)` on fixed input bar
- `visualViewport` API for keyboard-aware layout
- Long-press for message actions (instead of hover)
- Existing `<details>` pattern for reasoning is good for mobile space savings

---

## 7. Implementation Phases

### Phase 1: Multi-Provider Foundation (2-3 weeks)

**Goal**: Support Claude + OpenAI + Gemini + Ollama with a model selector.

1. Add `ruby_llm` gem to Gemfile
2. Create `Provider::RubyLlm` implementing `LlmConcept` via delegation
3. Add provider API key columns to `settings` table (anthropic_api_key, gemini_api_key, ollama_base_url)
4. Migrate existing `Assistant::Function` subclasses to `RubyLLM::Tool` subclasses
5. Replace hidden `ai_model` field with model selector dropdown
6. Add `default_ai_model` column to `families` table
7. Update `Provider::Registry` to support multiple LLM providers
8. Remove `latest_assistant_response_id` dependency — use conversation history instead
9. Update auto-categorizer and merchant detector to use RubyLLM

**Tests**: Update existing VCR cassettes for OpenAI, add cassettes for Claude/Gemini/Ollama.

### Phase 2: Expanded Function Tools (2-3 weeks)

**Goal**: AI can answer questions about all major financial features.

1. Implement Tier 1 functions: `get_holdings`, `get_projections`, `get_milestones`, `get_budgets`, `get_debt_optimization`, `get_loan_payoff`
2. Implement Tier 2 functions: `get_categories`, `get_tags`, `get_rules`, `get_merchants`, `get_connectivity_status`
3. Update system prompt to describe new capabilities
4. Add function privacy tests for all new functions

**Tests**: Unit tests per function, privacy tests ensuring family scoping.

### Phase 3: RAG Pipeline (2-3 weeks)

**Goal**: Semantic search over financial data for context-aware responses.

1. Add `neighbor` gem, enable pgvector extension
2. Create `embeddings` migration with HNSW index
3. Create `Embeddable` concern, add to Transaction, Account, Category, Tag, Milestone, AssistantMessage
4. Create `EmbedRecordJob` with content_hash deduplication
5. Create `RagContext` PORO for retrieval logic
6. Integrate RAG context injection into `Assistant::Configurable`
7. Add hybrid search (vector + tsvector keyword matching)
8. Add backfill rake task for existing data

**Tests**: Embedding generation, retrieval accuracy, family scoping, staleness detection.

### Phase 4: Chat UI Modernization (2-3 weeks)

**Goal**: Modern chat experience with rich content and message actions.

1. Add copy button on assistant messages (Stimulus controller)
2. Add regenerate button on last assistant message
3. Add thumbs up/down feedback (new `message_feedbacks` table)
4. Implement token batching in streaming (100ms flush)
5. Replace redirect with Turbo Stream in `MessagesController#create`
6. Add streaming cursor CSS animation
7. Accessibility fixes (role, aria-live, focus management, reduced motion)
8. Mobile safe area insets and keyboard handling

**Tests**: System tests for message actions, streaming behavior.

### Phase 5: Rich Content Blocks (1-2 weeks)

**Goal**: Financial data rendered as charts/tables in chat.

1. Define content block types (table, chart, summary_card, code)
2. Create Stimulus controllers for each content block type
3. Update function tools to return structured data for rendering
4. Add code syntax highlighting with copy button
5. Create financial chart rendering using existing D3.js components

**Tests**: Content block rendering, chart data formatting.

### Phase 6: Cost Tracking & Admin (1 week)

**Goal**: Operational visibility and budget controls.

1. Add token count columns to `messages` table
2. Store cost per message using RubyLLM pricing data
3. Add family-level AI budget setting
4. Create admin dashboard for AI usage monitoring
5. Add budget enforcement (reject or downgrade model when over budget)

---

## Appendix A: Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `OPENAI_ACCESS_TOKEN` | OpenAI API key | At least one provider required |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key | Optional |
| `GEMINI_API_KEY` | Google Gemini API key | Optional |
| `OLLAMA_BASE_URL` | Ollama server URL (e.g., `http://localhost:11434`) | Optional (self-hosted) |

### Self-Hosted Mode

Self-hosted users can run entirely locally with Ollama:
- LLM: Llama 3.x or Mistral via Ollama (tool calling support)
- Embeddings: BGE-M3 via Ollama
- No external API keys needed

### Managed Mode

Managed deployments should configure at minimum OpenAI + Claude for the best model selection. Gemini is optional. Ollama is typically not used in managed mode.

## Appendix B: Gem Dependencies

| Gem | Purpose | New? |
|-----|---------|------|
| `ruby_llm` | Multi-provider LLM abstraction | Yes |
| `neighbor` | pgvector ActiveRecord integration | Yes |
| `ruby-openai` | OpenAI API client (already present) | No — may be replaced by RubyLLM |

Both new gems are mature, actively maintained, and well-tested. `ruby_llm` has 1170+ model integrations. `neighbor` is by Andrew Kane (author of `pgvector` gem, `ankane/searchkick`, etc.).

## Appendix C: Key References

- [RubyLLM Documentation](https://rubyllm.com/)
- [RubyLLM Tools](https://rubyllm.com/tools/)
- [RubyLLM Rails Integration](https://rubyllm.com/rails/)
- [Neighbor Gem](https://github.com/ankane/neighbor)
- [pgvector](https://github.com/pgvector/pgvector)
- [Anthropic Claude Tool Use](https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview)
- [OpenAI Responses API](https://platform.openai.com/docs/guides/migrate-to-responses)
- [Gemini Function Calling](https://ai.google.dev/gemini-api/docs/function-calling)
- [Ollama](https://github.com/ollama/ollama)
- [Open Responses Standard](https://huggingface.co/blog/open-responses)
- [RAG on Rails with pgvector](https://jessewaites.com/blog/post/rag-on-rails/)
- [Financial Report Chunking for RAG (arXiv)](https://arxiv.org/html/2402.05131v2)
