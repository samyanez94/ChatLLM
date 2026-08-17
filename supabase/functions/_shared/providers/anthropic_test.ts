import type { ChatRequest } from "../chat_request.ts";
import {
  type AnthropicClientDependencies,
  createAnthropicResponse,
} from "./anthropic.ts";
import {
  assert,
  assertChatAPIError,
  assertEquals,
  captureError,
} from "../test_helpers.ts";

const request: ChatRequest = {
  provider: "anthropic",
  model: "claude-sonnet-5",
  messages: [
    { role: "user", content: "Hello" },
    { role: "assistant", content: "Hi" },
    { role: "user", content: "Continue" },
  ],
};

Deno.test("creates an Anthropic Messages API request", async () => {
  let capturedInput: string | URL | Request | undefined;
  let capturedInit: RequestInit | undefined;
  const response = await createAnthropicResponse(
    request,
    "request-123",
    dependencies((input, init) => {
      capturedInput = input;
      capturedInit = init;
      return Promise.resolve(anthropicSuccessResponse());
    }),
  );

  assertEquals(capturedInput, "https://api.anthropic.com/v1/messages");
  assertEquals(capturedInit?.method, "POST");
  const headers = new Headers(capturedInit?.headers);
  assertEquals(headers.get("x-api-key"), "test-api-key");
  assertEquals(headers.get("anthropic-version"), "2023-06-01");
  assertEquals(headers.get("X-Request-Id"), "request-123");
  assertEquals(JSON.parse(String(capturedInit?.body)), {
    model: "claude-sonnet-5",
    max_tokens: 8192,
    messages: request.messages,
  });
  assert(capturedInit?.signal instanceof AbortSignal);
  assertEquals(response, { outputText: "Hello world" });
});

Deno.test("combines text blocks and ignores other content", async () => {
  const response = await createAnthropicResponse(
    request,
    "request-123",
    dependencies(() =>
      Promise.resolve(Response.json({
        content: [
          { type: "thinking", thinking: "Reasoning" },
          { type: "text", text: "Safety " },
          { type: "text", text: "refusal" },
        ],
        stop_reason: "refusal",
      }))
    ),
  );
  assertEquals(response.outputText, "Safety refusal");
});

for (
  const [name, status, expectedCode, expectedStatus] of [
    ["rate limits", 429, "rate_limited", 429],
    ["provider errors", 500, "provider_error", 502],
  ] as const
) {
  Deno.test(`translates ${name}`, async () => {
    const error = await captureError(() =>
      createAnthropicResponse(
        request,
        "request-123",
        dependencies(() => Promise.resolve(new Response(null, { status }))),
      )
    );
    assertChatAPIError(error, expectedCode, expectedStatus);
  });
}

Deno.test("rejects an invalid provider response", async () => {
  const error = await captureError(() =>
    createAnthropicResponse(
      request,
      "request-123",
      dependencies(() => Promise.resolve(Response.json({ content: [] }))),
    )
  );
  assertChatAPIError(error, "provider_error", 502);
});

Deno.test("rejects missing server configuration", async () => {
  const error = await captureError(() =>
    createAnthropicResponse(request, "request-123", {
      apiKey: undefined,
      fetch: () => Promise.resolve(anthropicSuccessResponse()),
      timeoutMilliseconds: 1_000,
    })
  );
  assertChatAPIError(error, "internal_error", 500);
});

Deno.test("translates network failures", async () => {
  const error = await captureError(() =>
    createAnthropicResponse(
      request,
      "request-123",
      dependencies(() => {
        throw new TypeError("Network failure");
      }),
    )
  );
  assertChatAPIError(error, "service_unavailable", 503);
});

Deno.test("translates provider timeouts", async () => {
  const error = await captureError(() =>
    createAnthropicResponse(
      request,
      "request-123",
      dependencies(() => {
        throw new DOMException("Timed out", "TimeoutError");
      }),
    )
  );
  assertChatAPIError(error, "provider_timeout", 504);
});

function dependencies(
  fetch: AnthropicClientDependencies["fetch"],
  apiKey: string | undefined = "test-api-key",
): AnthropicClientDependencies {
  return { apiKey, fetch, timeoutMilliseconds: 1_000 };
}

function anthropicSuccessResponse(): Response {
  return Response.json({
    content: [
      { type: "text", text: "Hello " },
      { type: "text", text: "world" },
    ],
    stop_reason: "end_turn",
  });
}
