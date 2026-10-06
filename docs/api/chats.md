# Chat API Documentation

The Chat API allows external applications to interact with ROMS Finance's AI chat functionality.

## Getting Started

To obtain API credentials, navigate to Settings > API > Create Application.

## Authentication

All chat endpoints require authentication via OAuth2 or API keys. The chat endpoints also require the user to have AI features enabled (`ai_enabled: true`).

## Endpoints

### List Chats
```
GET /api/v1/chats
```

**Required Scope:** `read`

**Response:**
```json
{
  "chats": [
    {
      "id": "uuid",
      "title": "Chat title",
      "last_message_at": "2024-01-01T00:00:00Z",
      "message_count": 5,
      "error": null,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total_count": 50,
    "total_pages": 3
  }
}
```

### Get Chat
```
GET /api/v1/chats/:id
```

**Required Scope:** `read`

**Response:**
```json
{
  "id": "uuid",
  "title": "Chat title",
  "error": null,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z",
  "messages": [
    {
      "id": "uuid",
      "type": "user_message",
      "role": "user",
      "content": "Hello AI",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    },
    {
      "id": "uuid",
      "type": "assistant_message",
      "role": "assistant",
      "content": "Hello! How can I help you?",
      "model": "gpt-4",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "tool_calls": []
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 50,
    "total_count": 2,
    "total_pages": 1
  }
}
```

### Create Chat
```
POST /api/v1/chats
```

**Required Scope:** `write`

**Request Body:**
```json
{
  "title": "Optional chat title",
  "message": "Initial message to AI",
  "model": "gpt-4" // optional, defaults to gpt-4
}
```

**Response:** Same as Get Chat endpoint

### Update Chat
```
PATCH /api/v1/chats/:id
```

**Required Scope:** `write`

**Request Body:**
```json
{
  "title": "New chat title"
}
```

**Response:** Same as Get Chat endpoint

### Delete Chat
```
DELETE /api/v1/chats/:id
```

**Required Scope:** `write`

**Response:** 204 No Content

### Create Message
```
POST /api/v1/chats/:chat_id/messages
```

**Required Scope:** `write`

**Request Body:**
```json
{
  "content": "User message",
  "model": "gpt-4" // optional, defaults to gpt-4
}
```

**Response:**
```json
{
  "id": "uuid",
  "chat_id": "uuid",
  "type": "user_message",
  "role": "user",
  "content": "User message",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z",
  "ai_response_status": "pending",
  "ai_response_message": "AI response is being generated"
}
```

### Retry Last Message
```
POST /api/v1/chats/:chat_id/messages/retry
```

**Required Scope:** `write`

Retries or regenerates a durable assistant response attempt, using its original user
prompt and the explicitly ordered context that preceded that prompt. This is a
**POST**, including in the web UI; GET links do not initiate retries.

**Optional Request Body:**
```json
{
  "message_id": "source-assistant-message-uuid"
}
```

Always supply the actual assistant message ID when retrying a displayed reply.
The ID must belong to this chat, which must belong to the authenticated user.
Without an ID, retry selects the latest attempt linked to the latest explicitly
ordered user prompt, not the last row by timestamp. It never guesses the prompt
for an unlinked historical reply.

**Response: 202 Accepted**
```json
{
  "message": "Retry initiated",
  "attempt_id": "replacement-assistant-message-uuid",
  "message_id": "replacement-assistant-message-uuid",
  "origin_user_message_id": "original-user-message-uuid",
  "status": "pending"
}
```

`attempt_id` and `message_id` are aliases for the same durable assistant row;
`origin_user_message_id` identifies the original user prompt, not a copied prompt.
Repeated submissions for the same source return the same immediate replacement
without creating another attempt or enqueueing another operation. An active attempt
for that prompt is reused. A stale duplicate may return an already `complete` or
`failed` replacement; accepted does not imply a new provider execution. Retry that
replacement's ID to request a subsequent attempt after failure.

Invalid or unlinked legacy sources return **422** with actionable feedback to send
a new explicit prompt (or use the latest attempt where appropriate). A nonexistent
or cross-chat supplied ID returns **404**; inaccessible chats also return
404. Omitting `message_id` when no linked attempt exists returns 422.

## AI Response Handling

AI responses are processed asynchronously. When you create a message or chat with an initial message, the API returns immediately with the user message. The user-message creation callback reserves a pending assistant attempt and enqueues
it exactly once; the API does not enqueue a second job. The AI response is generated
in the background into that same durable row.

### Attempt history and authoritative context

The original prompt and all attempts remain in visible history, including empty or
partial failed attempts. A failed reply is marked FAILED in the web UI after reload;
pending replies show a generating label. Retry does not erase historical failure
labels or partial text. Regeneration retains the original successful answer until
a newer attempt succeeds. Only then is the old success marked as a previous version.
Duplicate-submit protection and same-origin active-attempt reuse prevent concurrent
regeneration of the same prompt.

Provider context contains explicitly ordered prompts and only the latest **complete**
answer per prompt. Failed and pending attempts, superseded successful answers, and
unlinked legacy messages are excluded from authoritative answer context. A failed
regeneration therefore does not displace the prior successful answer. Older unlinked
history stays visible with a warning; it cannot be retried by inferring its source.
Send a new prompt to continue. Retry execution uses context preceding its original
prompt, never later prompts or replies.

The retry response exposes attempt status and origin identity. The existing get-chat
history response is unchanged; its message IDs identify the rows to use as retry
sources.

### Checking for AI Responses

Currently, you need to poll the chat endpoint to check for new AI responses. Look for new messages with `type: "assistant_message"`.

### Available AI Models

Available models are configured per-instance. Check your instance's Settings > AI page for supported models.

### Tool Calls

The AI assistant can make tool calls to access user financial data. These appear in the `tool_calls` array of assistant messages:

```json
{
  "tool_calls": [
    {
      "id": "uuid",
      "function_name": "get_accounts",
      "function_arguments": {},
      "function_result": { ... },
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

## Error Handling

All endpoints return standard error responses:

```json
{
  "error": "error_code",
  "message": "Human readable error message",
  "details": ["Additional error details"] // optional
}
```

Common error codes:
- `unauthorized` - Invalid or missing authentication
- `forbidden` - Insufficient permissions or AI not enabled
- `not_found` - Resource not found
- `unprocessable_entity` - Invalid request data
- `rate_limit_exceeded` - Too many requests

## Rate Limits

Default: 100 requests/minute. Configurable via `RATE_LIMIT_*` environment variables.

Chat API endpoints are subject to the standard API rate limits based on your API key tier.
### Explicit interrupted-attempt recovery

A pending attempt is not automatically rerun on job redelivery. If no persisted
update has occurred for five minutes, the web UI offers **Stop and retry**.
API clients can explicitly request the same recovery with `message_id` and
`recover_interrupted: true`. Fresh pending attempts are returned unchanged.
Recovery preserves the old content/claim, marks the old attempt failed, and
reserves one linked replacement. Late output, token/tool records and completion
from the abandoned attempt are ignored. This is a logical output fence, not
proof that the old process ended or cancellation of an upstream provider call.
Previously completed answers stay authoritative until a newer attempt succeeds.

The global failure banner has no retry action: use the failed attempt's own
control so a delayed failure cannot accidentally regenerate a later prompt.
