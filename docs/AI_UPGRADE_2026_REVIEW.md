# Review: AI_UPGRADE_2026.md — Critical Feedback

## Context

This review evaluates the `docs/AI_UPGRADE_2026.md` upgrade plan against the actual codebase, project conventions (CLAUDE.md), and practical needs of ROMS Finance. The user has specifically flagged that model selection should NOT be user-facing — it should be admin-configured in settings, not a chat dropdown.

---

## 1. Model Selector in Chat — Remove It

**Document proposes** (Section 6.2): A dropdown model selector in the chat input area with provider grouping, capability badges, cost indicators, and per-conversation model override.

**Problem**: This violates the principle of "it should just work." Users are managing their finances, not shopping for AI models. Exposing model selection in the chat UI:
- Adds cognitive load to a financial tool
- Creates support burden ("which model should I pick?")
- Breaks the seamless experience — users shouldn't need to know what Claude vs GPT means
- The per-message `ai_model` column already exists and can be populated server-side from the family/admin default

**Recommendation**:
- Remove the model selector from the chat UI entirely
- Add `default_ai_model` to the **Settings** model (admin-level), not on the `families` table
- The hidden field in `_chat_form.html.erb` should pull from `Setting.default_ai_model` (or the family setting if multi-tenancy requires it)
- Remove references to "users can override per-conversation" from Section 3.6
- Remove Section 6.2 entirely
- Phase 1 step 5 ("Replace hidden ai_model field with model selector dropdown") should become: "Configure default AI model in admin settings"

---

## 2. RubyLLM — Good Choice, But Validate Maturity

**Document proposes** (Section 3.3): Replace the current `ruby-openai` + custom provider layer with `ruby_llm` gem v1.3.0+.

**Strengths**:
- Aligns with Convention 1 (minimize dependencies — one gem replaces 3+)
- The `acts_as_chat` / `acts_as_message` ActiveRecord pattern fits the existing model structure
- Unified tool calling DSL eliminates the provider-specific `ChatConfig`, `ChatParser`, `ChatStreamParser` classes

**Concerns**:
- **Maturity risk**: RubyLLM is relatively new compared to `ruby-openai`. The document claims "1170+ models" but doesn't address: what happens when a provider changes their API? How fast does RubyLLM ship patches? The project convention says "favor old and reliable over new and flashy."
- **Migration of `Assistant::Function`**: The existing `Assistant::Function` base class has a clean interface (`name`, `description`, `params_schema`, `call`, `strict_mode?`). Converting to `RubyLLM::Tool` subclasses means the tool definition is now owned by a third-party gem's DSL. If RubyLLM changes their tool API, all functions break. Consider keeping the existing `Assistant::Function` interface and writing an adapter that converts definitions to RubyLLM format, rather than inheriting from `RubyLLM::Tool` directly.
- **`acts_as_chat` vs existing models**: The `Chat` and `Message` models already have STI (`UserMessage`, `AssistantMessage`, `DeveloperMessage`), status enums, and tool call associations. Blindly adopting `acts_as_chat` may conflict. The document should specify exactly which RubyLLM ActiveRecord features will be used and which will be skipped.

**Recommendation**: Add a risk mitigation section. Consider wrapping RubyLLM behind the existing `Provider::LlmConcept` interface (which the document partially proposes in Step 2) rather than letting RubyLLM's patterns leak into the domain models.

---

## 3. RAG Pipeline — Over-Engineered for the Use Case

**Document proposes** (Section 4): Full RAG pipeline with pgvector, embeddings table, HNSW indexes, hybrid search, and background embedding jobs.

**Problems**:
- **Financial data is already structured**. The existing function tools (`get_transactions`, `get_accounts`, etc.) return precise, filtered, structured data. RAG is designed for unstructured text (documents, support tickets, knowledge bases). For "What did I spend on groceries last month?", the `get_transactions` function with a category filter is *more accurate* than semantic search over embedded transaction strings.
- **Embedding transactions is wasteful**. The document acknowledges each transaction is "under 100 tokens" — these are tiny, repetitive, highly structured records. Embedding "Transaction: $45.23 at Costco Wholesale on 2026-01-15. Category: Groceries." adds zero semantic value over a SQL query with `WHERE category = 'Groceries' AND date >= ?`.
- **The real gap is context, not search**. What the AI actually lacks is *proactive context* — knowing the user's financial situation without being asked. This is better solved by a system prompt that includes a brief financial summary (net worth, recent trends, account overview) rather than a full RAG pipeline.
- **Operational complexity**: pgvector extension, HNSW index tuning, embedding staleness detection, background jobs for every transaction create/update, backfill rake tasks — all for data that's already queryable via SQL.
- **Self-hosted burden**: BGE-M3 via Ollama for embeddings means self-hosted users need to run an embedding model in addition to their chat LLM. That's significant resource overhead for marginal benefit.

**What RAG IS useful for**:
- Chat history search (finding past conversations about specific topics)
- Possibly notes/memos attached to accounts or transactions (free-text user content)

**Recommendation**:
- **Defer RAG entirely to a later phase** (or cut it). Focus on expanding the function tools first (Phase 2) — that's where the real value gap is.
- If RAG is kept, scope it to **chat history only** (AssistantMessage embeddings), not structured financial records. The function tools already provide structured data retrieval.
- Remove transaction/account/category/tag embeddings from the plan.

---

## 4. Four Provider Families — Too Many for Launch

**Document proposes**: OpenAI + Anthropic + Gemini + Ollama all in Phase 1.

**Concerns**:
- Supporting 4 providers in Phase 1 means 4x the testing surface, 4x the VCR cassettes, and edge cases for each provider's streaming quirks.
- Gemini's Ruby story is weak (no standalone SDK — "use through RubyLLM" is the only option).
- Ollama tool calling is model-dependent and unreliable compared to commercial APIs.

**Recommendation**:
- Phase 1: OpenAI + Anthropic (the two most mature, best tool-calling support)
- Phase 2 or later: Gemini + Ollama (once the abstraction is proven)
- This reduces Phase 1 scope significantly and still delivers the key value (choice between GPT and Claude)

---

## 5. Expanded Function Tools — Strong, But Missing Prioritization Logic

**Document proposes** (Section 5): 15+ function tools across 3 tiers.

**Strengths**: The tier breakdown is sensible. The Tier 1 functions (`get_holdings`, `get_projections`, `get_milestones`, `get_budgets`, `get_debt_optimization`, `get_loan_payoff`) cover the biggest gaps.

**Concerns**:
- **Tool overload**: With 15+ tools, the system prompt and tool definitions will consume significant context window. Each tool definition with its JSON schema is ~200-400 tokens. 15 tools = 3,000-6,000 tokens just for tool definitions. This is fine for large-context models but matters for Ollama/smaller models.
- **No write operations planned**: All tools are read-only. The document doesn't mention whether the AI should ever be able to *do* things (create a transaction, set a budget, add a category). This is probably intentional for safety, but should be explicitly stated as a design decision with a path for future write tools.
- **Missing: `get_net_worth_summary`**: A simple high-level function that returns net worth, total assets, total liabilities, and month-over-month change. The `get_balance_sheet` exists but the AI needs a quick "here's where the user stands" tool for conversational context.

**Recommendation**:
- Explicitly state "all tools are read-only by design" in the document
- Consider dynamic tool loading — only include tools relevant to the user's accounts (e.g., don't include `get_holdings` if the user has no investment accounts, don't include `get_debt_optimization` if no loans exist)
- Add a `get_financial_summary` tool that provides a high-level overview for conversational context

---

## 6. Chat UI Modernization — Mostly Good, Some Cuts Needed

**Strengths**: Token batching (100ms flush), Turbo Stream response instead of redirect, accessibility fixes, and streaming cursor are all solid improvements.

**Cut or defer**:
- **Conversation branching / edit + fork** (Section 6.3): "Edit + regenerate" with `parent_message_id` is complex branching logic for minimal user value in a financial assistant. Users aren't writing creative fiction — they're asking about their money. Cut this.
- **Rich content blocks** (Section 6.4 / Phase 5): Interactive sortable tables and D3.js charts *inside chat messages* sounds impressive but is over-engineered. The app already has dedicated dashboard pages with charts and tables. The AI should link users to the relevant page rather than recreating dashboard widgets inline. A simple well-formatted markdown table is sufficient for chat.
- **"Coming soon" placeholder buttons** (mentioned in 6.1): The document correctly identifies these as clutter but doesn't say to remove them. They should just be removed entirely, not replaced with real features yet.

**Keep**:
- Copy button on messages
- Regenerate on last assistant message
- Thumbs up/down feedback (valuable for model quality evaluation)
- Token batching
- Turbo Stream submit
- All accessibility fixes
- Mobile safe area handling

---

## 7. Cost Tracking — Scope It Down

**Document proposes** (Section 3.8 / Phase 6): Per-message cost tracking, family-level budgets, admin dashboard, and model downgrade when over budget.

**Concerns**:
- **Budget enforcement with model downgrade** is complex — what does "downgrade" mean? Silently switching to a cheaper model breaks the "it just works" principle. If there's a budget, either warn the admin or disable AI chat, don't silently degrade quality.
- **Admin dashboard** is premature. Simple database queries are fine for now. A full dashboard is an entire feature.

**Recommendation**:
- Keep: per-message token count storage (it's free with RubyLLM)
- Keep: cost-per-message calculation
- Defer: budget enforcement, admin dashboard, model downgrade logic
- Add: a simple admin page showing total AI spend this month (one number, one query)

---

## 8. Missing Items the Document Should Address

### 8.1 Error Handling Strategy
The document mentions "generic errors" as a current limitation (Section 6.1) but doesn't propose a solution beyond listing it. Need specific error types: rate limit (retry after X), invalid API key (admin notification), content policy (user-facing message), network timeout (retry with backoff), context length exceeded (truncate history).

### 8.2 Conversation History Management
With `previous_response_id` being removed (OpenAI-specific), the document needs to address: how much conversation history is sent with each request? Full history will eventually exceed context windows. Need a truncation or summarization strategy — e.g., keep last N messages, or summarize older messages.

### 8.3 Testing Strategy for Multi-Provider
The document says "update existing VCR cassettes" but doesn't address: how do you test that the same user question produces reasonable results across different providers? Provider parity testing is important if the admin can switch models.

### 8.4 Migration Path for Existing Chats
When switching from OpenAI's `previous_response_id` to full conversation history, existing chats that rely on `previous_response_id` will break. Need a migration plan (likely just: old chats can't be continued, start fresh).

### 8.5 Rate Limiting
No mention of rate limiting AI requests per user/family. Without this, a single user could rack up significant API costs.

### 8.6 Fallback Strategy
If the configured provider is down, should the system try another provider? Or just show an error? This needs a decision.

---

## 9. Summary of Recommended Changes

| Section | Action | Priority |
|---------|--------|----------|
| Model Selector (6.2) | **Remove entirely**. Admin sets model in Settings. | Must |
| RAG Pipeline (Section 4 / Phase 3) | **Defer or cut**. Expand function tools first. If kept, scope to chat history only. | Must |
| Provider count (Phase 1) | **Reduce to OpenAI + Anthropic** for Phase 1. Add Gemini/Ollama later. | Should |
| Conversation branching (6.3) | **Cut**. Not needed for financial assistant. | Should |
| Rich content blocks (6.4 / Phase 5) | **Cut or heavily simplify**. Markdown tables are sufficient. Link to dashboards. | Should |
| Cost budget/downgrade (Phase 6) | **Simplify**. Track costs, show total, defer enforcement. | Should |
| RubyLLM tool migration | **Wrap, don't inherit**. Keep `Assistant::Function` interface, adapt to RubyLLM. | Should |
| Error handling | **Add section** with specific error types and responses. | Must |
| Conversation history mgmt | **Add section** on truncation/summarization strategy. | Must |
| Rate limiting | **Add section** on per-user/family request limits. | Must |
| Existing chat migration | **Add section** on `previous_response_id` deprecation path. | Should |
| Dynamic tool loading | **Add** — only register tools relevant to user's account types. | Nice to have |
| AI Memory (new) | **Add Phase 5** — structured profile + summaries + memory tool for persistent context. | Must |

---

## 10. Revised Phase Plan (Recommended)

### Phase 1: Multi-Provider Foundation (2 weeks)
- Add `ruby_llm` gem
- Create `Provider::RubyLlm` implementing `LlmConcept`
- Support OpenAI + Anthropic only
- Admin-level model setting in `Setting` (not user-facing)
- Adapt existing `Assistant::Function` to work with RubyLLM (wrapper, not inheritance)
- Remove `previous_response_id` dependency, implement conversation history with truncation
- Update auto-categorizer and merchant detector
- Error handling with specific error types
- Rate limiting per user

### Phase 2: Expanded Function Tools (2-3 weeks)
- Tier 1 + Tier 2 functions (as proposed)
- Dynamic tool loading based on user's account types
- Add `get_financial_summary` overview tool
- Privacy tests for family scoping

### Phase 3: Chat UI Improvements (1-2 weeks)
- Token batching (100ms flush)
- Turbo Stream submit (replace redirect)
- Copy button, regenerate, thumbs up/down
- Accessibility fixes
- Mobile handling
- Remove "coming soon" placeholder buttons
- Streaming cursor

### Phase 4: Additional Providers + Cost Tracking (1-2 weeks)
- Add Gemini and Ollama support
- Per-message cost tracking
- Simple admin spend summary page

### Phase 5: AI Memory — Persistent User Context (1-2 weeks)

The AI should "learn" about users over time without expensive RAG infrastructure. This phase adds three lightweight memory layers that keep token costs minimal.

#### Layer 1: Structured User Profile (~200 tokens/request)

Add a `ai_profile` JSONB column to the `Family` model. After each conversation ends, make one cheap extraction call asking the model to pull out any new facts or preferences. Merge results into the existing profile (append, don't replace). Inject the full profile into the system prompt on every new chat.

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

#### Layer 2: Conversation Summaries (~500 tokens/request)

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

#### Layer 3: Memory Tool — AI-Initiated Recall (`save_memory` / `get_memories`)

Give the AI a `save_memory` function tool it can call mid-conversation when it learns something important. This is the most flexible layer — the AI decides what's worth remembering.

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
- Duplicate detection: before saving, check if a memory with similar content already exists (simple string similarity or exact category+content match)
- All memories loaded into system prompt on each chat (~1000 tokens for 50 short memories)
- Admin can view, pin, and delete memories from the family settings page

**System prompt injection order:**
1. Base instructions (existing)
2. User profile (Layer 1) — "About this user: ..."
3. Memories (Layer 3) — "Things I remember: ..."
4. Recent conversation summaries (Layer 2) — "Recent conversations: ..."
5. Tool definitions

**Total per-request token overhead:** ~1,700 tokens across all three layers. At current pricing, this is fractions of a cent per message.

#### Why Not RAG for Memory?

Memories are small (50 items x 280 chars = ~14KB). Loading all of them into the system prompt is cheaper and more reliable than maintaining a vector index, running similarity searches, and risking relevant memories being missed by embedding distance thresholds. RAG only makes sense when the corpus is too large to fit in context — 50 short memories is not that.

#### Testing approach:
- Unit tests for `Family#update_ai_profile` with fixture conversations
- Unit tests for `Chat#generate_summary`
- Unit tests for `SaveMemory` function tool
- Integration test: create chat → end chat → verify profile updated and summary generated
- Privacy test: memories are family-scoped, never leak across families
- Capacity test: verify 51st memory prunes oldest non-pinned memory

### Phase 6 (Future): RAG for Chat History
- Only if there's demonstrated need after function tools and memory layers are live
- Scope to chat history search, not structured financial data
