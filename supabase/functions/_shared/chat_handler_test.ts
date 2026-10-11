import { handleChatRequest } from "./chat_handler.ts";
import { maximumInputBytes } from "./chat_request.ts";
import { createOpenRouterResponse } from "./providers/openrouter.ts";
import { assert, assertEquals } from "./test_helpers.ts";

const payload = {
  provider: "google",
  model: "gemini-3.5-flash",
  messages: [
    { role: "user", content: "Earlier" },
    { role: "assistant", content: "Earlier reply" },
    { role: "user", content: "Continue" },
  ],
  continuation_id: "legacy_interaction",
};

Deno.test("the endpoint preserves app IDs and resumes legacy chats through OpenRouter", async () => {
  let upstreamBody: unknown;
  const response = await handleChatRequest(
    makeRequest(payload),
    (request) =>
      createOpenRouterResponse(request, {
        apiKey: "test-key",
        timeoutMilliseconds: 1_000,
        fetch: (_input, init) => {
          upstreamBody = JSON.parse(String(init?.body));
          return Promise.resolve(Response.json({
            id: "gen_new",
            model: "google/gemini-3.5-flash",
            choices: [{ message: { content: "Restored reply" } }],
          }));
        },
      }),
  );
  assertEquals(response.status, 200);
  assert(Boolean(response.headers.get("X-Request-Id")));
  assertEquals(await response.json(), {
    provider: "google",
    model: "gemini-3.5-flash",
    output_text: "Restored reply",
  });
  assertEquals(upstreamBody, {
    model: "google/gemini-3.5-flash",
    messages: payload.messages,
    stream: false,
  });
});

for (
  const [name, request, expectedCode, expectedStatus] of [
    [
      "method",
      new Request("https://example.com/chat"),
      "method_not_allowed",
      405,
    ],
    [
      "JSON",
      new Request("https://example.com/chat", { method: "POST", body: "{" }),
      "invalid_request",
      400,
    ],
    ["shape", makeRequest({}), "invalid_request", 400],
    [
      "size",
      makeRequest({
        ...payload,
        messages: [{
          role: "user",
          content: "x".repeat(maximumInputBytes + 1),
        }],
      }),
      "input_too_large",
      413,
    ],
    [
      "provider",
      makeRequest({ ...payload, provider: "unknown" }),
      "unsupported_provider",
      422,
    ],
    [
      "model",
      makeRequest({ ...payload, model: "unknown" }),
      "unsupported_model",
      422,
    ],
  ] as const
) {
  Deno.test(`the endpoint rejects invalid ${name} before an upstream request`, async () => {
    let called = false;
    const response = await handleChatRequest(
      request,
      (chatRequest) =>
        createOpenRouterResponse(chatRequest, {
          apiKey: "test-key",
          timeoutMilliseconds: 1_000,
          fetch: () => {
            called = true;
            return Promise.resolve(Response.json({}));
          },
        }),
    );
    assertEquals(called, false);
    assertEquals(response.status, expectedStatus);
    const body = await response.json();
    assertEquals(body.error.code, expectedCode);
    assert(typeof body.error.request_id === "string");
    if (expectedStatus === 405) {
      assertEquals(response.headers.get("Allow"), "POST");
    }
  });
}

Deno.test("upstream credit failures retain the safe public error envelope", async () => {
  const response = await handleChatRequest(
    makeRequest(payload),
    (request) =>
      createOpenRouterResponse(request, {
        apiKey: "test-key",
        timeoutMilliseconds: 1_000,
        fetch: () =>
          Promise.resolve(
            Response.json({ error: "private details" }, { status: 402 }),
          ),
      }),
  );
  assertEquals(response.status, 503);
  const body = await response.json();
  assertEquals(body.error.code, "service_unavailable");
  assert(typeof body.error.request_id === "string");
  assert(body.error.message.includes("credit or spending limit"));
  assert(!JSON.stringify(body).includes("private details"));
});

function makeRequest(body: unknown): Request {
  return new Request("https://example.com/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}
