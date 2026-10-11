# Chat streaming contract

`POST /functions/v1/chat` accepts an optional boolean `stream`. Omit it or set
it to `false` for the existing JSON response. Authentication, model IDs, the
full `messages` transcript, and input limits are unchanged. Legacy
`continuation_id` values remain accepted and ignored; there is no server-side
conversation state.

```json
{
  "provider": "openai",
  "model": "gpt-6-luna",
  "messages": [{ "role": "user", "content": "Hello" }],
  "stream": true
}
```

A successful streaming connection returns HTTP 200 with
`Content-Type: text/event-stream; charset=utf-8`,
`Cache-Control: no-cache,
no-transform`, and `X-Request-Id`. Each SSE event
contains a JSON `data` payload:

```text
event: delta
data: {"text":"Hello"}

event: delta
data: {"text":" there!"}

event: completed
data: {"provider":"openai","model":"gpt-6-luna"}
```

Append each `delta.text` exactly as received. `completed` echoes the app's model
identity, not an upstream model slug. It is emitted once, only after
OpenRouter's `[DONE]` marker and at least one non-whitespace text delta. Usage,
reasoning, provider IDs, and heartbeat comments are not forwarded. Repeated
finish reasons in upstream usage frames do not generate duplicate completion
events.

Validation, configuration, and upstream HTTP failures before streaming starts
retain the existing JSON error envelope and HTTP status. After streaming starts,
a failure produces one terminal SSE event instead:

```text
event: error
data: {"error":{"code":"provider_error","message":"The provider returned an invalid or incomplete stream.","request_id":"…"}}
```

Clients must inspect the HTTP status before parsing SSE, handle both error
paths, and treat EOF without `completed` as interrupted. An `error` event never
precedes a `completed` event. Raw upstream errors are never forwarded. Do not
automatically retry after displaying partial output: another request starts a
new generation.

The backend applies a 60-second total upstream deadline (including connection
and body reading); it does not reset for every token. A timeout after headers
produces `provider_timeout`. Cancelling the response body or aborting the
incoming request aborts the upstream fetch and releases its reader. Actual
provider-side generation and billing cancellation depend on OpenRouter's
selected hosting endpoint.

The parser accepts incremental UTF-8, LF/CRLF/CR line endings, multiline data,
and comments. Frames are limited to 1,048,576 decoded characters to bound
buffering. Reading downstream drives upstream consumption; the backend does not
accumulate the full answer. A malformed frame, upstream error, empty answer, or
premature EOF terminates with a safe error.

## Verification

```sh
deno test supabase/functions/_shared
deno lint supabase/functions
deno fmt --check supabase/functions
deno check --no-lock --config supabase/functions/chat/deno.json supabase/functions/chat/index.ts
```

The streaming tests use controlled upstream streams to verify incremental
delivery, fragmentation, compatibility, terminal events, error sanitization, and
cancellation. A deployed smoke test is still needed to verify buffering and
client-disconnect propagation through the Supabase gateway. The iOS client must
opt in separately; this backend change does not change its current non-streaming
behavior.
