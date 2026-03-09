# AI Capabilities Upgrade — 2026 Architecture Plan

**Date**: March 2026
**Scope**: Multi-provider LLM support, expanded AI function coverage, AI memory, modernized chat UI
**Last Updated**: March 9, 2026

---

## Progress Summary

| Phase       | Status        | Description                                                    |
| ----------- | ------------- | -------------------------------------------------------------- |
| **Phase 1** | **COMPLETED** | Multi-provider LLM foundation (OpenAI + Anthropic via RubyLLM) |
| **Phase 2** | **COMPLETED** | 12 new AI function tools + dynamic loading                     |
| **Phase 3** | Not started   | Chat UI improvements                                           |
| **Phase 4** | Not started   | Additional providers (Gemini/Ollama) + cost tracking           |
| **Phase 5** | Not started   | AI memory (persistent user context)                            |
| Phase 6     | Future        | RAG for chat history (deferred)                                |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State (Post Phase 1+2)](#2-current-state-post-phase-12)
3. [Multi-Provider LLM Architecture](#3-multi-provider-llm-architecture)
4. [Expanded AI Function Tools](#4-expanded-ai-function-tools)
5. [AI Memory — Persistent User Context](#5-ai-memory--persistent-user-context)
6. [Chat UI Modernization](#6-chat-ui-modernization)
7. [Error Handling & Operational Concerns](#7-error-handling--operational-concerns)
8. [Implementation Phases](#8-implementation-phases)

---

## 1. Executive Summary

The AI system has been upgraded from a single-provider (OpenAI-only) setup with 4 function tools to a **multi-provider architecture** supporting OpenAI and Anthropic models with **16 function tools** covering all major financial features. The remaining work focuses on chat UI modernization (Phase 3), additional providers and cost tracking (Phase 4), and AI memory (Phase 5).

### Key Design Decisions

| Decision                   | Choice                                  | Rationale                                                                                                        |
| -------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Multi-provider abstraction | **RubyLLM** (`ruby_llm` gem)            | Rails-native, unified tool calling. One gem replaces 3+ provider SDKs.                                           |
| Tool migration             | **Wrap, don't inherit**                 | `FunctionToolAdapter` converts `Assistant::Function` instances to RubyLLM tools. Our interface, their execution. |
| Model selection            | **Admin-level setting**                 | `Setting.default_ai_model` — users don't pick models. It just works.                                             |
| Streaming                  | Turbo Streams + Action Cable (existing) | Already in place. Token batching deferred to Phase 3.                                                            |
| Cost tracking              | **Deferred to Phase 4**                 | RubyLLM provides token counts; DB columns + admin page needed.                                                   |
| RAG pipeline               | **Deferred**                            | Financial data is structured — function tools query via SQL.                                                     |
| Function tools             | **Read-only by design**                 | All 16 tools are read-only. Write operations require future safety review.                                       |

---

## 2. Current State (Post Phase 1+2)

### 2.1 What Was Built

**Provider layer** (`app/models/provider/`):

- `Provider::RubyLlm` — **NEW** — multi-provider adapter implementing `LlmConcept` via RubyLLM gem
- `Provider::RubyLlm::FunctionToolAdapter` — **NEW** — converts `Assistant::Function` instances to `RubyLLM::Tool` subclasses with real execution
- `Provider::RubyLlm::AutoCategorizer` — **NEW** — provider-agnostic auto-categorization
- `Provider::RubyLlm::AutoMerchantDetector` — **NEW** — provider-agnostic merchant detection
- `Provider::LlmConcept` — **UPDATED** — `ChatResponse` now includes `tool_calls_log`; `chat_response` signature updated to accept `function_instances:` and `messages:`
- `Provider::Registry` — **UPDATED** — `:llm` concept routes to `ruby_llm_provider`
- `config/initializers/ruby_llm.rb` — **NEW** — configures OpenAI + Anthropic API keys

**Removed** (OpenAI-specific chat code):

- ~~`Provider::Openai::ChatConfig`~~ — **DELETED**
- ~~`Provider::Openai::ChatParser`~~ — **DELETED**
- ~~`Provider::Openai::ChatStreamParser`~~ — **DELETED**
- `Provider::Openai#chat_response` — **REMOVED** (auto-categorize/merchant detect retained)

**Assistant layer** (`app/models/assistant/`):

- `Assistant` — **UPDATED** — builds conversation history (last 20 messages), passes function instances to provider, persists tool call logs, specific error handling for rate limits/auth/timeout
- `Assistant::Responder` — **SIMPLIFIED** — no more manual follow-up responses; RubyLLM handles the full tool call loop
- `Assistant::Configurable` — **UPDATED** — dynamic tool loading based on user's data, expanded system prompt describing all capabilities
- 16 function tools (4 original + 12 new)

**Settings & UI**:

- `Setting` — **UPDATED** — added `anthropic_api_key`, `default_ai_model` fields
- Admin hosting page — **UPDATED** — new AI settings section with model selector and API key fields
- `_chat_form.html.erb` — **UPDATED** — uses `Setting.default_ai_model`, removed "Coming soon" placeholder buttons

**Chat model**:

- `Chat#update_latest_response!` — **REMOVED** (was OpenAI `previous_response_id` dependency)
- Conversation history sent with each request (last 20 messages)

### 2.2 Function Tools — Full Coverage

| #   | Function                  | Status   | Source                             |
| --- | ------------------------- | -------- | ---------------------------------- |
| 1   | `get_accounts`            | Existing | `Account`                          |
| 2   | `get_transactions`        | Existing | `Transaction::Search`              |
| 3   | `get_balance_sheet`       | Existing | `Balance::ChartSeriesBuilder`      |
| 4   | `get_income_statement`    | Existing | `IncomeStatement`                  |
| 5   | `get_financial_summary`   | **NEW**  | `Family`, `Account`                |
| 6   | `get_holdings`            | **NEW**  | `Holding`, `Security`, `Trade`     |
| 7   | `get_projections`         | **NEW**  | `FamilyProjectionCalculator`       |
| 8   | `get_milestones`          | **NEW**  | `Milestone`                        |
| 9   | `get_budgets`             | **NEW**  | `Budget`, `BudgetCategory`         |
| 10  | `get_debt_optimization`   | **NEW**  | `DebtOptimizationStrategy`         |
| 11  | `get_loan_payoff`         | **NEW**  | `LoanPayoffCalculator`             |
| 12  | `get_categories`          | **NEW**  | `Category`, `Entry`                |
| 13  | `get_tags`                | **NEW**  | `Tag`, `Tagging`                   |
| 14  | `get_rules`               | **NEW**  | `Rule`, `Condition`, `Action`      |
| 15  | `get_merchants`           | **NEW**  | `Merchant`, `Entry`                |
| 16  | `get_connectivity_status` | **NEW**  | `PlaidItem`, `SnapTradeConnection` |

**Dynamic loading**: Tools are only registered when the user has relevant data (e.g., `get_holdings` only if investment accounts exist).

### 2.3 What's Still OpenAI-Specific

| Component                                  | Status           | Notes                                                                                                      |
| ------------------------------------------ | ---------------- | ---------------------------------------------------------------------------------------------------------- |
| `Provider::Openai::AutoCategorizer`        | Retained         | Still works for backwards compat; `Family::AutoCategorizer` now routes through `Provider::RubyLlm` instead |
| `Provider::Openai::AutoMerchantDetector`   | Retained         | Same as above                                                                                              |
| `ruby-openai` gem                          | Still in Gemfile | Can be removed once OpenAI-specific auto-categorizer/detector files are deleted                            |
| `Chat#latest_assistant_response_id` column | Still in DB      | Column exists but unused; migration to drop it can be added                                                |

### 2.4 Remaining Work (Not Done in Phase 1+2)

- **Rate limiting** (Section 7.4) — `Rack::Attack` throttle not yet implemented
- **VCR cassettes / test updates** — existing tests reference deleted OpenAI chat code
- **Privacy tests** for new functions — `function_privacy_test.rb` not yet extended
- **Unit tests** for new function tools
- **`Gemfile.lock`** — `bundle install` could not run (Ruby 3.3.6 vs required 3.4.4 in CI environment)

---

## 3–4. Multi-Provider LLM Architecture & Expanded Function Tools

_Sections 3 and 4 from the original document remain accurate as architectural reference. The implementation follows the documented approach with one key architectural difference:_

**Tool execution model change**: The original plan described a two-step flow (provider returns tool requests → `FunctionToolCaller` executes → results sent back). The implemented approach lets **RubyLLM handle the full tool call loop** internally — `FunctionToolAdapter` creates `RubyLLM::Tool` subclasses whose `execute` methods delegate to `Assistant::Function#call`. Tool calls are logged and persisted after the fact via `tool_calls_log` on `ChatResponse`.

---

## 5. AI Memory — Persistent User Context

**Status: NOT STARTED — Phase 5**

No changes from the original design. Implementation requires:

1. **Migration**: Add `ai_profile` (JSONB) to `families` table
2. **Migration**: Add `summary` (text) to `chats` table
3. **Migration**: Create `ai_memories` table
4. **Model**: `AiMemory` with family association, category, content, TTL
5. **Function tool**: `Assistant::Function::SaveMemory` — AI-initiated memory creation
6. **Background job**: Profile extraction + chat summarization on conversation end
7. **System prompt**: Inject profile, memories, recent summaries into `Assistant::Configurable`
8. **Admin UI**: View/clear profile, manage memories in family settings

### Three Memory Layers

| Layer                      | Purpose                                       | Token Cost                  | Trigger             |
| -------------------------- | --------------------------------------------- | --------------------------- | ------------------- |
| **Structured Profile**     | User facts/preferences on `Family#ai_profile` | ~200/request                | End of conversation |
| **Conversation Summaries** | 2-3 sentence chat summaries on `Chat#summary` | ~500/request (10 summaries) | End of conversation |
| **Memory Tool**            | AI-initiated `save_memory` function call      | ~1000/request (50 memories) | Mid-conversation    |

**Total overhead**: ~1,700 tokens/request. Fractions of a cent per message.

---

## 6. Chat UI Modernization

**Status: NOT STARTED — Phase 3**

### 6.1 Already Done (as part of Phase 1+2)

- [x] ~~Hardcoded model~~ → now uses `Setting.default_ai_model`
- [x] ~~"Coming soon" placeholder buttons~~ → removed entirely
- [x] ~~Generic errors~~ → specific error handling for rate limits, auth, timeouts

### 6.2 Still To Do

1. **Copy button** on messages — Stimulus controller, clipboard API
2. **Regenerate button** on last assistant message — extends existing `retry_last_message!`
3. **Thumbs up/down feedback** — new `message_feedbacks` table (message_id, rating, comment)
4. **Token batching** — buffer in `AssistantResponseJob`, flush every 100ms (reduces DB writes ~10x)
5. **Turbo Stream response** — replace `redirect_to` in `MessagesController#create` with Turbo Stream append
6. **Streaming cursor** — CSS blinking cursor animation
7. **Optimistic UI** — append user message client-side via Stimulus before server confirms
8. **Accessibility**:
   - `role="log"` and `aria-live="polite"` on `#messages`
   - `aria-live="assertive"` on thinking indicator
   - `aria-label` on each message
   - Respect `prefers-reduced-motion` for `animate-pulse`
   - Focus management: return focus to textarea after submit
   - Keyboard shortcuts: `Ctrl+/` to focus input
9. **Mobile**:
   - Safe area insets on fixed input bar
   - `visualViewport` API for keyboard-aware layout
   - Long-press for message actions

---

## 7. Error Handling & Operational Concerns

### 7.1 Error Handling — PARTIALLY IMPLEMENTED

**Done** (in `Assistant#respond_to`):

- Rate limit (HTTP 429) → user-friendly message
- Invalid API key (401/403) → log + user message
- Network timeout → user message
- Generic fallback → `chat.add_error(e)`

**Not done**:

- Content policy detection (provider-specific refusal patterns)
- Context length exceeded → automatic truncation + retry
- Retry with exponential backoff (currently shows error immediately)

### 7.2 Conversation History — IMPLEMENTED

- Last 20 messages sent with each request
- System prompt + instructions always included
- Context length auto-truncation NOT yet implemented

### 7.3 Migration Path — PARTIALLY DONE

- `latest_assistant_response_id` no longer used in code
- DB column still exists (migration to drop it not yet created)
- Existing chats continue working via full history

### 7.4 Rate Limiting — NOT IMPLEMENTED

Needs `Rack::Attack` throttle on `MessagesController#create`.

---

## 8. Implementation Phases

### Phase 1: Multi-Provider Foundation — COMPLETED ✅

**Commit**: `c5b9f21` on `claude/plan-ai-upgrade-8I19l`

All 10 items completed:

1. ✅ Added `ruby_llm` gem to Gemfile
2. ✅ Created `Provider::RubyLlm` implementing `LlmConcept`
3. ✅ Added `anthropic_api_key`, `default_ai_model` to Settings + admin UI
4. ✅ Built `FunctionToolAdapter` converting `Assistant::Function` → RubyLLM tools
5. ✅ Admin model selection in settings (replaces hardcoded `"gpt-4.1"`)
6. ✅ Updated `Provider::Registry` (`:llm` → `ruby_llm_provider`)
7. ✅ Removed `latest_assistant_response_id` dependency — conversation history with 20-message truncation
8. ✅ Migrated auto-categorizer/merchant detector to provider-agnostic RubyLLM
9. ✅ Error handling for rate limits, auth errors, timeouts
10. ❌ Rate limiting via `Rack::Attack` — deferred

**Not done**: `bundle install` (Ruby version mismatch in dev environment), test updates, rate limiting.

### Phase 2: Expanded Function Tools — COMPLETED ✅

**Commit**: `c5b9f21` (same commit as Phase 1)

All 6 items completed:

1. ✅ `get_financial_summary` overview tool
2. ✅ Tier 1: `get_holdings`, `get_projections`, `get_milestones`, `get_budgets`, `get_debt_optimization`, `get_loan_payoff`
3. ✅ Tier 2: `get_categories`, `get_tags`, `get_rules`, `get_merchants`, `get_connectivity_status`
4. ✅ Dynamic tool loading in `Assistant::Configurable`
5. ✅ Updated system prompt with new capabilities
6. ❌ Privacy tests for new functions — not yet written

**Not done**: Unit tests for each function, privacy tests, Tier 3 tools (transfers, forecast accuracy, data quality, exchange rates, tax info).

### Phase 3: Chat UI Improvements — NOT STARTED

**Goal**: Modern chat experience with message actions and accessibility.

1. Add copy button on messages (Stimulus controller)
2. Add regenerate button on last assistant message
3. Add thumbs up/down feedback (new `message_feedbacks` table + migration)
4. Implement token batching in streaming (100ms flush)
5. Replace redirect with Turbo Stream in `MessagesController#create`
6. Add streaming cursor CSS animation
7. Accessibility fixes (role, aria-live, focus management, reduced motion)
8. Mobile safe area insets and keyboard handling

**Tests**: System tests for message actions, streaming behavior.

### Phase 4: Additional Providers + Cost Tracking — NOT STARTED

**Goal**: Gemini and Ollama support, operational cost visibility.

1. Add Gemini provider support via RubyLLM
2. Add Ollama provider support via RubyLLM
3. Add `gemini_api_key`, `ollama_base_url` to admin settings
4. Add token count columns to `messages` table (migration)
5. Store cost per message using RubyLLM pricing data
6. Create simple admin page showing total AI spend this month

**Tests**: VCR cassettes for Gemini/Ollama, cost calculation tests.

### Phase 5: AI Memory — NOT STARTED

**Goal**: AI remembers user context across conversations.

1. Add `ai_profile` JSONB column to `Family` (migration)
2. Add `summary` text column to `Chat` (migration)
3. Create `ai_memories` table (migration)
4. Implement `Family#update_ai_profile` with cheap extraction call
5. Implement `Chat#generate_summary` on conversation end
6. Create `Assistant::Function::SaveMemory` tool
7. Integrate all three layers into system prompt injection (`Assistant::Configurable`)
8. Add admin page for viewing/clearing profile and managing memories
9. Background job for profile extraction + summarization on chat close

**Tests**: Unit tests for profile extraction, summarization, SaveMemory tool. Privacy tests for family scoping. Capacity test for 50-memory limit.

### Phase 6 (Future): RAG for Chat History

Deferred. Only if demonstrated need after function tools and memory layers are live.

---

## Appendix A: Environment Variables

| Variable              | Purpose                  | Required                         | Phase |
| --------------------- | ------------------------ | -------------------------------- | ----- |
| `OPENAI_ACCESS_TOKEN` | OpenAI API key           | At least one provider required   | 1 ✅  |
| `ANTHROPIC_API_KEY`   | Anthropic Claude API key | Optional                         | 1 ✅  |
| `DEFAULT_AI_MODEL`    | Default model override   | Optional (defaults to `gpt-4.1`) | 1 ✅  |
| `GEMINI_API_KEY`      | Google Gemini API key    | Optional                         | 4     |
| `OLLAMA_BASE_URL`     | Ollama server URL        | Optional (self-hosted)           | 4     |

## Appendix B: Gem Dependencies

| Gem           | Purpose                        | Status                                           |
| ------------- | ------------------------------ | ------------------------------------------------ |
| `ruby_llm`    | Multi-provider LLM abstraction | **Added** (Phase 1)                              |
| `ruby-openai` | OpenAI API client              | Retained (used by legacy auto-categorizer files) |

## Appendix C: Key File Inventory (Post Phase 1+2)

### New Files

| File                                                       | Purpose                               |
| ---------------------------------------------------------- | ------------------------------------- |
| `config/initializers/ruby_llm.rb`                          | RubyLLM provider configuration        |
| `app/models/provider/ruby_llm.rb`                          | Multi-provider LLM adapter            |
| `app/models/provider/ruby_llm/function_tool_adapter.rb`    | Function → RubyLLM tool converter     |
| `app/models/provider/ruby_llm/auto_categorizer.rb`         | Provider-agnostic auto-categorization |
| `app/models/provider/ruby_llm/auto_merchant_detector.rb`   | Provider-agnostic merchant detection  |
| `app/views/settings/hostings/_ai_settings.html.erb`        | Admin AI settings partial             |
| `app/models/assistant/function/get_financial_summary.rb`   | Net worth overview tool               |
| `app/models/assistant/function/get_holdings.rb`            | Investment positions tool             |
| `app/models/assistant/function/get_projections.rb`         | Future value projections tool         |
| `app/models/assistant/function/get_milestones.rb`          | Financial goals tool                  |
| `app/models/assistant/function/get_budgets.rb`             | Budget vs actual tool                 |
| `app/models/assistant/function/get_debt_optimization.rb`   | Debt strategy analysis tool           |
| `app/models/assistant/function/get_loan_payoff.rb`         | Loan amortization tool                |
| `app/models/assistant/function/get_categories.rb`          | Category spending tool                |
| `app/models/assistant/function/get_tags.rb`                | Tags with usage tool                  |
| `app/models/assistant/function/get_rules.rb`               | Transaction rules tool                |
| `app/models/assistant/function/get_merchants.rb`           | Merchant spending tool                |
| `app/models/assistant/function/get_connectivity_status.rb` | Connection health tool                |

### Deleted Files

| File                                               | Reason              |
| -------------------------------------------------- | ------------------- |
| `app/models/provider/openai/chat_config.rb`        | Replaced by RubyLLM |
| `app/models/provider/openai/chat_parser.rb`        | Replaced by RubyLLM |
| `app/models/provider/openai/chat_stream_parser.rb` | Replaced by RubyLLM |

### Modified Files

| File                                              | Change                                                      |
| ------------------------------------------------- | ----------------------------------------------------------- |
| `Gemfile`                                         | Added `ruby_llm`                                            |
| `app/models/setting.rb`                           | Added `anthropic_api_key`, `default_ai_model`               |
| `app/models/provider/llm_concept.rb`              | Updated `ChatResponse` + `chat_response` signature          |
| `app/models/provider/registry.rb`                 | `:llm` → `ruby_llm_provider`                                |
| `app/models/provider/openai.rb`                   | Removed `chat_response` method                              |
| `app/models/assistant.rb`                         | Conversation history, error handling, tool call persistence |
| `app/models/assistant/responder.rb`               | Simplified (RubyLLM handles tool loop)                      |
| `app/models/assistant/configurable.rb`            | Dynamic tool loading, expanded system prompt                |
| `app/models/chat.rb`                              | Removed `update_latest_response!`                           |
| `app/models/family/auto_categorizer.rb`           | Uses LLM registry instead of direct OpenAI                  |
| `app/models/family/auto_merchant_detector.rb`     | Uses LLM registry instead of direct OpenAI                  |
| `app/views/messages/_chat_form.html.erb`          | `Setting.default_ai_model`, removed placeholder buttons     |
| `app/views/settings/hostings/show.html.erb`       | Added AI settings section                                   |
| `app/controllers/settings/hostings_controller.rb` | Accepts AI setting params                                   |

## Appendix D: Key References

- [RubyLLM Documentation](https://rubyllm.com/)
- [RubyLLM Tools](https://rubyllm.com/tools/)
- [RubyLLM Rails Integration](https://rubyllm.com/rails/)
- [Anthropic Claude Tool Use](https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview)
- [OpenAI Responses API](https://platform.openai.com/docs/guides/migrate-to-responses)
- [Gemini Function Calling](https://ai.google.dev/gemini-api/docs/function-calling)
- [Ollama](https://github.com/ollama/ollama)
