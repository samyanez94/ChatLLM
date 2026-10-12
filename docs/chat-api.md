# Chat API Contract

Version: v1

This document defines the contract between the ChatLLM iOS client and the
ChatLLM backend. The backend owns the OpenRouter credential, validates supported
model-author and model combinations, and translates OpenRouter responses and
errors into this stable API. The iOS app continues to use Supabase credentials;
OpenRouter is a backend implementation detail.

## Endpoint

```http
POST /functions/v1/chat
apikey: <supabase-publishable-key>
Content-Type: application/json
```

The endpoint requires the Supabase project's publishable key. The key identifies
the calling Supabase project but does not authenticate or identify an end user.
Requests using any HTTP method other than `POST` are rejected.

The publishable key is safe to include in the iOS application and must not be
treated as a secret. Supabase secret keys and the OpenRouter API key must never be
included in the client or accepted as client credentials by this endpoint.

## Request

```json
{
  "provider": "openai",
  "model": "gpt-5.6-luna",
  "messages": [
    { "role": "user", "content": "Hello" }
  ]
}
```

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `provider` | string | Yes | Stable model-author identifier: `openai`, `anthropic`, or `google`. This is not an OpenRouter hosting endpoint. |
| `model` | string | Yes | Stable ChatLLM model identifier selected by the client; mapped to an OpenRouter model ID by the backend. |
| `messages` | array | Yes | Non-empty transcript of `user` and `assistant` messages ending with a user message. |
| `messages[].role` | string | Yes | Either `user` or `assistant`. |
| `messages[].content` | string | Yes | Non-empty text content for the message. |
| `stream` | boolean | No | Set to `true` for SSE. Omitted or `false` keeps the JSON response. |
| `continuation_id` | string | No | Legacy opaque identifier. Accepted for compatibility and ignored; the full transcript is always used. |

Unknown fields may be ignored for forward compatibility. Missing fields,
incorrect field types, empty identifiers, invalid roles, and empty content
produce an `invalid_request` error.

The v1 maximum combined message content is 32 KiB (32,768 bytes) when encoded
as UTF-8. A transcript exceeding that limit produces an `input_too_large` error.

## Success Response

```http
HTTP/1.1 200 OK
Content-Type: application/json
```

```json
{
  "provider": "openai",
  "model": "gpt-5.6-luna",
  "output_text": "Hi! How can I help?"
}
```

| Field | Type | Description |
| --- | --- | --- |
| `provider` | string | Provider that generated the response. |
| `model` | string | Model that generated the response. |
| `stream` | boolean | No | Set to `true` for SSE. Omitted or `false` keeps the JSON response. |
| `continuation_id` | string | Legacy optional field; omitted by the OpenRouter backend. |
| `output_text` | string | Generated assistant response. |

The returned `provider` and `model` must match the accepted request.

## Provider and Model Validation

The client selects both `provider` and `model`. The backend is authoritative
about which provider and model combinations are supported.

The backend validates requests in this order:

1. Validate the request shape and transcript constraints.
2. Confirm that the provider is supported.
3. Confirm that the model is supported by that provider.
4. Map the model to its allowlisted OpenRouter ID.
5. Invoke the OpenRouter adapter with the full transcript.

The new-chat picker offers eight remote models. The backend additionally keeps
eight legacy model IDs available for saved conversations and older app builds.
The supported catalog is equivalent to:

```ts
const supportedModels = {
  openai: new Set([
    "gpt-6-luna",
    "gpt-6.1-sol",
    "gpt-5.6-luna",
    "gpt-5.6-terra",
    "gpt-5.6-sol",
    "gpt-6-astra",
  ]),
  anthropic: new Set([
    "claude-opus-5-5",
    "claude-sonnet-5-5",
    "claude-haiku-5-5",
    "claude-opus-5",
    "claude-sonnet-5",
    "claude-haiku-4-5",
  ]),
  google: new Set([
    "gemini-3.8-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
  ]),
} as const
```

An unknown provider produces `unsupported_provider`. A known provider paired
with an unsupported model produces `unsupported_model`. Unsupported requests
must be rejected before calling OpenRouter.

### OpenRouter Mapping and Routing

The app and saved conversations retain the existing IDs. The backend uses this
explicit mapping (verified against OpenRouter's catalog on October 11, 2026):

| Provider | ChatLLM model ID | OpenRouter model ID |
| --- | --- | --- |
| `openai` | `gpt-6-luna` | `openai/gpt-6-luna` |
| `openai` | `gpt-6.1-sol` | `openai/gpt-6.1-sol` |
| `anthropic` | `claude-opus-5-5` | `anthropic/claude-opus-5.5` |
| `anthropic` | `claude-sonnet-5-5` | `anthropic/claude-sonnet-5.5` |
| `anthropic` | `claude-haiku-5-5` | `anthropic/claude-haiku-5.5` |
| `google` | `gemini-3.8-flash` | `google/gemini-3.8-flash` |
| `openai` | `gpt-5.6-luna` | `openai/gpt-5.6-luna` |
| `openai` | `gpt-5.6-terra` | `openai/gpt-5.6-terra` |
| `openai` | `gpt-5.6-sol` | `openai/gpt-5.6-sol` |
| `openai` | `gpt-6-astra` | `openai/gpt-6-astra` |
| `anthropic` | `claude-opus-5` | `anthropic/claude-opus-5` |
| `anthropic` | `claude-sonnet-5` | `anthropic/claude-sonnet-5` |
| `anthropic` | `claude-haiku-4-5` | `anthropic/claude-haiku-4.5` |
| `google` | `gemini-3.6-flash` | `google/gemini-3.6-flash` |
| `google` | `gemini-3.5-flash` | `google/gemini-3.5-flash` |
| `google` | `gemini-3.5-flash-lite` | `google/gemini-3.5-flash-lite` |

The current picker includes GPT-6 Luna, GPT-6.1 Sol, GPT-6 Astra, Claude Opus 5.5,
Sonnet 5.5, Haiku 5.5, Gemini 3.8 Flash, and Gemini 3.5 Flash-Lite. All other IDs
in this table retain their original meaning for existing conversations. The iOS
factory uses the full supported catalog when restoring chats and the current
catalog when creating them. No saved model ID is rewritten during this update.
Deploy this expanded allowlist before releasing the updated iOS picker.

The adapter calls `POST https://openrouter.ai/api/v1/chat/completions` with
`stream` matching the requested response mode and a server-side `OPENROUTER_API_KEY`. It uses OpenRouter's
automatic hosting-endpoint selection and default endpoint fallback behavior for
the selected model. It does not request fallback to a different model or override
the account's privacy settings. The public response echoes the original ChatLLM
provider/model IDs, not OpenRouter's response model slug.

GPT-6 Astra requests use `reasoning: { effort: "low" }`. This default is set by
the backend; the public request does not expose a reasoning option. Other models
use OpenRouter's model/provider defaults. Only assistant text is returned to the
app; reasoning and upstream metadata are not included.

## Legacy Continuations

The backend accepts a syntactically valid `continuation_id` from older clients
but ignores it. It always sends the complete `messages` transcript to OpenRouter
and omits `continuation_id` from successful responses. An OpenRouter generation
ID is not a conversation continuation and is never returned in this field.

Existing clients already handle an absent continuation: the next successful
reply clears the saved ID, and later turns continue using the full transcript.
Legacy continuation compatibility does not require rewriting chat IDs. The existing
32 KiB transcript limit still applies.

## Streaming and iOS Behavior

The iOS client opts into `stream: true` and consumes the response using
`URLSession.bytes(for:)`. The [SSE contract](../supabase/functions/_shared/STREAMING.md)
defines `delta`, `completed`, and `error` events. The client validates the selected
model on completion and treats EOF without a completion event as an interruption.
Errors before streaming begins remain ordinary HTTP/JSON errors.

Both remote providers and Apple's `LanguageModelSession.streamResponse` report
cumulative text snapshots through `ChatProviding.streamReply`. Updates are consumed
in the generation task; no independent token producer or unbounded queue is used.
The view model retains each snapshot immediately. Live replies use SwiftStreamingMarkdown’s
`StreamedMarkdownView` through a small `StreamedMarkdownSource` adapter. Its
`AsyncStream` buffers only the newest full-text snapshot, so a slow renderer does
not accumulate stale updates. Completion delivers the final snapshot and finishes
the sequence. The live reply keeps the same row identity when saved, allowing its animation to finish in place.
Saved history uses `MarkdownView` without animation. Stop and Reduce Motion switch
to that static renderer to discard any in-progress fade. Leaving the bubble also
finishes its source; completed replies return as static history. Persistence does
not wait for the animation.

The renderer uses [SwiftStreamingMarkdown v0.7.0](https://github.com/microsoft/SwiftStreamingMarkdown/releases/tag/v0.7.0),
pinned to its release commit because its own dependencies include revision pins
that SwiftPM does not allow beneath a version-based dependency.

The Stop button cancels the generation task and its URLSession request. Leaving a
conversation or backgrounding the app also cancels generation. Partial text is
saved with `stopped` or `interrupted` status; complete replies use `completed`.
Generation with no visible text does not insert an empty assistant message. Active
text stays in memory until generation ends, so a forced process termination can
lose the active partial reply. Completed and interrupted replies survive reopening.

Before each generation, providers synchronize with the saved transcript. The next request therefore includes the same partial answer that
the user sees. Apple's session is rebuilt from that transcript as well. Status
labels are display metadata, not text inserted into model prompts.

This development update adds `ChatMessage.status` directly to the initial SwiftData
schema. No production migration is provided; an incompatible existing development
store may require reinstalling the app after preserving any wanted test chats.

Live checks confirmed completion and client cancellation against deployed Supabase.
The client closes its connection; provider-side generation/billing cancellation
and gateway-to-worker disconnect propagation are not directly observable in these
checks. Actual Apple Intelligence generation requires supported hardware.

## Error Response

All errors use the same envelope:

```json
{
  "error": {
    "code": "unsupported_model",
    "message": "Model 'example-model' is not supported by provider 'openai'.",
    "request_id": "7E22C711-35EB-4511-92AF-A5DB55BD4C77"
  }
}
```

| Field | Type | Description |
| --- | --- | --- |
| `error.code` | string | Stable, machine-readable error code. |
| `error.message` | string | Safe, human-readable explanation. Not intended for program logic. |
| `error.request_id` | string | Backend-generated identifier for tracing and support. |

Clients must make decisions using `error.code`, not `error.message`.

The Supabase gateway validates the `apikey` header before the Chat API handler
runs. A missing or invalid publishable key therefore uses Supabase's gateway
error envelope rather than the Chat API envelope. Clients must treat any `401`
response as `invalid_api_key` regardless of the response body.

The backend must not expose provider credentials, raw upstream response bodies,
stack traces, or other sensitive implementation details. Provider request IDs
may be recorded in server logs but are not a replacement for the backend
`request_id`.

## Error Codes

| HTTP status | Code | Meaning |
| ---: | --- | --- |
| `400` | `invalid_request` | The JSON is malformed or a field is missing or invalid. |
| `401` | `invalid_api_key` | The Supabase publishable key is missing or invalid. The response body may use Supabase's gateway error format. |
| `405` | `method_not_allowed` | The request did not use `POST`. |
| `413` | `input_too_large` | The combined transcript content exceeds the backend's configured limit. |
| `422` | `unsupported_provider` | The provider identifier is valid but unsupported. |
| `422` | `unsupported_model` | The provider is supported, but the model is not supported by it. |
| `422` | `invalid_continuation` | Reserved for legacy backends; the OpenRouter adapter does not emit this code. |
| `429` | `rate_limited` | The caller or application exceeded a configured quota. |
| `500` | `internal_error` | The backend encountered an unexpected failure. |
| `502` | `provider_error` | The upstream provider rejected or failed the request. |
| `503` | `service_unavailable` | The backend is temporarily unavailable. |
| `504` | `provider_timeout` | The upstream provider did not respond in time. |

Every error response, including unexpected server failures, must use the common
error envelope whenever the backend is able to produce a response.

### OpenRouter Error Translation

OpenRouter `401` responses become `503 service_unavailable` with a safe
configuration message, not `401 invalid_api_key` (which refers to the app's
Supabase credential). OpenRouter `402` credit or spending-limit errors also become
`503 service_unavailable`, with a message identifying the credit/spending limit.
`429` maps to `rate_limited`, `408`/`504` and request timeouts map to
`provider_timeout`, and `503` or transport failures map to `service_unavailable`.
Other upstream failures map to `provider_error`.

Malformed JSON, empty/non-text replies, and error payloads returned with HTTP 200
are rejected as `provider_error`. Raw upstream errors are never forwarded. The
60-second timeout covers both the upstream request and reading its response.
The backend does not automatically retry requests.

## Security Model

The publishable key is a project identifier, not a user credential or a secret.
Anyone who obtains it can attempt to invoke the endpoint. This v1 tradeoff keeps
the personal-development client simple and is not intended to provide per-user
authorization or abuse prevention.

The backend must compensate by allowlisting provider and model combinations,
limiting request sizes, and relying on conservative upstream budgets and usage
alerts. Authentication can be upgraded to Supabase user sessions in a future
contract version before broader distribution. The endpoint must accept only
publishable client credentials; Supabase secret keys remain restricted to
trusted server-to-server operations.

## Example: Unsupported Provider

Request:

```json
{
  "provider": "example-provider",
  "model": "example-model",
  "messages": [{ "role": "user", "content": "Hello" }]
}
```

Response:

```http
HTTP/1.1 422 Unprocessable Content
```

```json
{
  "error": {
    "code": "unsupported_provider",
    "message": "Provider 'example-provider' is not supported.",
    "request_id": "780AC32F-E655-4994-A97C-A44C523E5518"
  }
}
```

## Example: Unsupported Model

Request:

```json
{
  "provider": "openai",
  "model": "example-model",
  "messages": [{ "role": "user", "content": "Hello" }]
}
```

Response:

```http
HTTP/1.1 422 Unprocessable Content
```

```json
{
  "error": {
    "code": "unsupported_model",
    "message": "Model 'example-model' is not supported by provider 'openai'.",
    "request_id": "7E22C711-35EB-4511-92AF-A5DB55BD4C77"
  }
}
```

## Versioning

This is version `v1` of the contract. Backward-compatible additions may be made
without changing the version, including adding optional response fields, error
codes, providers, or models. Removing or renaming fields, changing field types,
or changing existing field semantics requires a new contract version.
