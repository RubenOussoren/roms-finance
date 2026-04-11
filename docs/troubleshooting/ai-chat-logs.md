# How to View AI Chat Logs in Production

This guide explains how to inspect AI chat activity (LLM calls, errors, tool usage, costs) in a Dockerized production environment.

## 1. Rails Application Logs (stdout)

AI chat logs use the `[AI Chat]` prefix via `Rails.logger`. In Docker, these go to stdout.

```bash
# Live tail of all Rails logs (includes AI chat lines)
docker logs -f roms-finance-web

# Filter to just AI chat lines
docker logs roms-finance-web 2>&1 | grep "\[AI Chat\]"
```

**What you'll see:**
- `[AI Chat] Setup took XXms (N functions, model=...)` -- per-request setup timing
- `[AI Chat] TTFT XXms` -- time-to-first-token (latency from API call to first streamed token)
- Model fallback warnings (WARN level) when requested model is unavailable
- Authentication errors (ERROR level) for invalid API keys

**Source:** `app/models/assistant.rb`

## 2. Database: Chat History & Messages

All chat data is persisted. Use the Rails console:

```bash
docker exec -it roms-finance-web bin/rails console
```

### Recent chats

```ruby
Chat.order(created_at: :desc).limit(10).pluck(:id, :title, :created_at)
```

### Messages for a specific chat

```ruby
chat = Chat.last  # or Chat.find("uuid")
chat.messages.order(:created_at).each do |m|
  puts "#{m.type} [#{m.status}] #{m.ai_model} | tokens: #{m.input_tokens}/#{m.output_tokens} | cost: #{m.cost_cents}c"
  puts m.content.truncate(200)
  puts "---"
end
```

### Failed messages

```ruby
Message.where(status: :failed).order(created_at: :desc).limit(10).each do |m|
  puts "Chat: #{m.chat_id} | #{m.created_at} | #{m.content.truncate(100)}"
end
```

### Chat-level errors (stored as JSONB)

```ruby
Chat.where.not(error: nil).each do |c|
  puts "#{c.id}: #{c.error}"
end
```

### Cost analysis

```ruby
# Total cost across all messages
AssistantMessage.sum(:cost_cents)

# Cost per day
AssistantMessage.group("DATE(created_at)").sum(:cost_cents)

# Most expensive chats
Chat.joins(:messages)
    .where(messages: { type: "AssistantMessage" })
    .group("chats.id", "chats.title")
    .order(Arel.sql("SUM(messages.cost_cents) DESC"))
    .limit(10)
    .sum("messages.cost_cents")
```

## 3. Tool Calls (Function Execution Logs)

Every AI function call is stored in the `tool_calls` table:

```ruby
# Recent tool calls
ToolCall.order(created_at: :desc).limit(20).each do |tc|
  puts "#{tc.function_name} | args: #{tc.function_arguments} | result size: #{tc.function_result.to_json.size} bytes"
end

# Tool calls for a specific chat
chat = Chat.last
ToolCall.joins(:message).where(messages: { chat_id: chat.id }).each do |tc|
  puts "#{tc.function_name}: #{tc.function_arguments}"
end

# Most-used functions
ToolCall.group(:function_name).order("count_all DESC").count
```

## 4. Sidekiq Job Logs

AI responses run via `AssistantResponseJob` (high priority) and `AiMemoryExtractionJob` (default priority).

```bash
# Sidekiq logs in Docker
docker logs -f roms-finance-worker   # if separate worker container

# If web and worker share a container:
docker logs -f roms-finance-web 2>&1 | grep -i "sidekiq\|assistant.*job\|memory.*job"
```

### Sidekiq Web UI

If mounted (check `config/routes.rb`), visit `/sidekiq` in your browser to see job queues, retries, and dead jobs.

## 5. Debug Mode

Set `AI_DEBUG_MODE=true` to expose developer/system messages in the chat UI via the `Chat::Debuggable` concern.

```yaml
# Add to your docker-compose.yml under environment:
AI_DEBUG_MODE: "true"
# Then restart the container
```

## 6. AI Memory & Profile Data

```ruby
# View extracted AI memories for a family
family = Family.first
family.ai_memories.each { |m| puts "#{m.category}: #{m.content}" }

# View auto-extracted profile
family.ai_profile
```

## Quick Reference

| What | Where | How |
|------|-------|-----|
| LLM call timing/errors | Rails stdout | `docker logs -f roms-finance-web \| grep "AI Chat"` |
| Chat history & content | `chats` + `messages` tables | Rails console queries |
| Token usage & costs | `messages.input_tokens/output_tokens/cost_cents` | Rails console queries |
| Function tool calls | `tool_calls` table | Rails console queries |
| Job failures | Sidekiq logs / Web UI | `docker logs` or `/sidekiq` |
| Debug mode | ENV var | `AI_DEBUG_MODE=true` |
