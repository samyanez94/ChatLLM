# Chat API Contract

Version: v1

This document defines the contract between the ChatLLM iOS client and the
ChatLLM backend. The backend owns provider credentials, validates supported
provider and model combinations, and translates provider-specific responses
and errors into this stable API.

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
treated as a secret. Supabase secret keys and provider API keys must never be
included in the client or accepted as client credentials by this endpoint.

## Request

```json
{
  "provider": "openai",
  "model": "gpt-5.6-luna",
  "messages": [
    { "role": "user", "content": "Hello" }
  ],
  "continuation_id": "resp_123"
}
```

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `provider` | string | Yes | Stable provider identifier: `openai` or `anthropic`. |
| `model` | string | Yes | Provider-specific model identifier selected by the client. |
| `messages` | array | Yes | Non-empty transcript of `user` and `assistant` messages ending with a user message. |
| `messages[].role` | string | Yes | Either `user` or `assistant`. |
| `messages[].content` | string | Yes | Non-empty text content for the message. |
| `continuation_id` | string | No | Opaque identifier returned by the previous successful response. |

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
  "continuation_id": "resp_456",
  "output_text": "Hi! How can I help?"
}
```

| Field | Type | Description |
| --- | --- | --- |
| `provider` | string | Provider that generated the response. |
| `model` | string | Model that generated the response. |
| `continuation_id` | string | Optional opaque identifier to include in the next request when the provider supports continuations. |
| `output_text` | string | Generated assistant response. |

The returned `provider` and `model` must match the accepted request.

## Provider and Model Validation

The client selects both `provider` and `model`. The backend is authoritative
about which provider and model combinations are supported.

The backend validates requests in this order:

1. Validate the request shape and transcript constraints.
2. Confirm that the provider is supported.
3. Confirm that the model is supported by that provider.
4. Validate the continuation, when one is supplied.
5. Invoke the selected provider adapter.

In v1, the supported catalog is equivalent to:

```ts
const supportedModels = {
  openai: new Set([
    "gpt-5.6-luna",
    "gpt-5.6-terra",
    "gpt-5.6-sol",
  ]),
  anthropic: new Set([
    "claude-opus-5",
    "claude-sonnet-5",
    "claude-haiku-4-5",
  ]),
} as const
```

An unknown provider produces `unsupported_provider`. A known provider paired
with an unsupported model produces `unsupported_model`. Unsupported requests
must be rejected before calling the upstream provider.

## Continuations

`continuation_id` is opaque to the client. The client must not parse, modify,
or manufacture it.

A continuation is valid only for the conversation, provider, and model that
produced it. The client must begin a new conversation when the selected
provider or model changes.

For OpenAI, the backend maps `continuation_id` to OpenAI's
`previous_response_id`. When no continuation is available, it sends the full
transcript. Anthropic always receives the full transcript because its Messages
API is stateless; Anthropic responses omit `continuation_id`.

If a continuation is expired, malformed, unknown, or incompatible with the
requested provider or model, the backend returns `invalid_continuation`.

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
| `422` | `invalid_continuation` | The continuation cannot be used with this request. |
| `429` | `rate_limited` | The caller or application exceeded a configured quota. |
| `500` | `internal_error` | The backend encountered an unexpected failure. |
| `502` | `provider_error` | The upstream provider rejected or failed the request. |
| `503` | `service_unavailable` | The backend is temporarily unavailable. |
| `504` | `provider_timeout` | The upstream provider did not respond in time. |

Every error response, including unexpected server failures, must use the common
error envelope whenever the backend is able to produce a response.

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
