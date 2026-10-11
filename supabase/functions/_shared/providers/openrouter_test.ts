import type { ChatRequest } from "../chat_request.ts";
import {
  createOpenRouterResponse,
  type OpenRouterClientDependencies,
} from "./openrouter.ts";
import {
  assert,
  assertChatAPIError,
  assertEquals,
  captureError,
} from "../test_helpers.ts";

const request: ChatRequest = {
  provider: "openai",
  model: "gpt-5.6-luna",
  messages: [
    { role: "user", content: "Earlier" },
    { role: "assistant", content: "Earlier reply" },
    { role: "user", content: "Hello" },
  ],
};

for (
  const continuationId of [undefined, "resp_previous", "interaction_previous"]
) {
  Deno.test(`sends the full transcript with continuation ${continuationId}`, async () => {
    let capturedInput: string | URL | Request | undefined;
    let capturedInit: RequestInit | undefined;
    const response = await createOpenRouterResponse(
      { ...request, continuationId },
      dependencies((input, init) => {
        capturedInput = input;
        capturedInit = init;
        return Promise.resolve(successResponse());
      }),
    );

    assertEquals(
      capturedInput,
      "https://openrouter.ai/api/v1/chat/completions",
    );
    assertEquals(capturedInit?.method, "POST");
    const headers = new Headers(capturedInit?.headers);
    assertEquals(headers.get("Authorization"), "Bearer test-api-key");
    assertEquals(headers.get("Content-Type"), "application/json");
    assertEquals(JSON.parse(String(capturedInit?.body)), {
      model: "openai/gpt-5.6-luna",
      messages: request.messages,
      stream: false,
    });
    assert(capturedInit?.signal instanceof AbortSignal);
    assertEquals(response, { outputText: "Hello world" });
  });
}

Deno.test("maps Haiku's legacy ID to its OpenRouter ID", async () => {
  let body: Record<string, unknown> | undefined;
  await createOpenRouterResponse(
    { ...request, provider: "anthropic", model: "claude-haiku-4-5" },
    dependencies((_input, init) => {
      body = JSON.parse(String(init?.body));
      return Promise.resolve(successResponse());
    }),
  );
  assertEquals(body?.model, "anthropic/claude-haiku-4.5");
});

Deno.test("preserves Astra's low reasoning setting", async () => {
  let body: unknown;
  await createOpenRouterResponse(
    { ...request, model: "gpt-6-astra", continuationId: "resp_previous" },
    dependencies((_input, init) => {
      body = JSON.parse(String(init?.body));
      return Promise.resolve(successResponse());
    }),
  );
  assertEquals(body, {
    model: "openai/gpt-6-astra",
    messages: request.messages,
    stream: false,
    reasoning: { effort: "low" },
  });
});

for (
  const [provider, model, code] of [
    ["unknown", "gpt-5.6-luna", "unsupported_provider"],
    ["openai", "unknown", "unsupported_model"],
    ["google", "gpt-5.6-luna", "unsupported_model"],
    ["openai", "toString", "unsupported_model"],
    ["__proto__", "unknown", "unsupported_provider"],
  ]
) {
  Deno.test(`rejects ${provider}/${model} before contacting OpenRouter`, async () => {
    let called = false;
    const error = await captureError(() =>
      createOpenRouterResponse(
        { ...request, provider, model },
        dependencies(() => {
          called = true;
          return Promise.resolve(successResponse());
        }),
      )
    );
    assertChatAPIError(error, code, 422);
    assertEquals(called, false);
  });
}

for (
  const [status, code, publicStatus] of [
    [400, "provider_error", 502],
    [401, "service_unavailable", 503],
    [402, "service_unavailable", 503],
    [403, "provider_error", 502],
    [404, "provider_error", 502],
    [408, "provider_timeout", 504],
    [429, "rate_limited", 429],
    [500, "provider_error", 502],
    [502, "provider_error", 502],
    [503, "service_unavailable", 503],
    [504, "provider_timeout", 504],
  ] as const
) {
  Deno.test(`translates HTTP ${status} without exposing upstream details`, async () => {
    const error = await captureError(() =>
      createOpenRouterResponse(
        { ...request, continuationId: "resp_legacy" },
        dependencies(() =>
          Promise.resolve(
            Response.json({ error: "private-upstream-details" }, { status }),
          )
        ),
      )
    );
    assertChatAPIError(error, code, publicStatus);
    assert(error instanceof Error);
    assert(!error.message.includes("private-upstream-details"));
    if (status === 402) {
      assert(error.message.includes("credit or spending limit"));
    }
  });
}

for (
  const [name, body] of [
    ["missing choices", {}],
    ["empty choices", { choices: [] }],
    ["missing message", { choices: [{}] }],
    ["null content", { choices: [{ message: { content: null } }] }],
    ["empty content", { choices: [{ message: { content: "  " } }] }],
    ["nontext content", { choices: [{ message: { content: [] } }] }],
    ["HTTP 200 error", {
      error: { message: "private" },
      choices: [{ message: { content: "Partial" } }],
    }],
    ["failed completion", {
      choices: [{ finish_reason: "error", message: { content: "Partial" } }],
    }],
  ] as const
) {
  Deno.test(`rejects ${name}`, async () => {
    const error = await captureError(() =>
      createOpenRouterResponse(
        request,
        dependencies(() => Promise.resolve(Response.json(body))),
      )
    );
    assertChatAPIError(error, "provider_error", 502);
  });
}

Deno.test("rejects malformed JSON", async () => {
  const error = await captureError(() =>
    createOpenRouterResponse(
      request,
      dependencies(() => Promise.resolve(new Response("not JSON"))),
    )
  );
  assertChatAPIError(error, "provider_error", 502);
});

Deno.test("returns text only, without reasoning or generation identifiers", async () => {
  const response = await createOpenRouterResponse(
    request,
    dependencies(() =>
      Promise.resolve(Response.json({
        id: "gen_123",
        choices: [{
          finish_reason: "stop",
          message: {
            content: "  Hello\nworld  ",
            reasoning: "Internal reasoning",
          },
        }],
      }))
    ),
  );
  assertEquals(response, { outputText: "  Hello\nworld  " });
});

for (const apiKey of [undefined, "", "  "]) {
  Deno.test(`rejects missing server configuration: ${JSON.stringify(apiKey)}`, async () => {
    let called = false;
    const error = await captureError(() =>
      createOpenRouterResponse(request, {
        ...dependencies(() => {
          called = true;
          return Promise.resolve(successResponse());
        }),
        apiKey,
      })
    );
    assertChatAPIError(error, "internal_error", 500);
    assertEquals(called, false);
  });
}

Deno.test("translates network failures", async () => {
  const error = await captureError(() =>
    createOpenRouterResponse(
      request,
      dependencies(() => {
        throw new TypeError("Network failure");
      }),
    )
  );
  assertChatAPIError(error, "service_unavailable", 503);
});

Deno.test("translates timeouts while fetching headers", async () => {
  const error = await captureError(() =>
    createOpenRouterResponse(
      request,
      dependencies(() => {
        throw new DOMException("Timed out", "TimeoutError");
      }),
    )
  );
  assertChatAPIError(error, "provider_timeout", 504);
});

Deno.test("translates timeouts while reading the response body", async () => {
  const error = await captureError(() =>
    createOpenRouterResponse(
      request,
      dependencies(() =>
        Promise.resolve(
          new Response(
            new ReadableStream({
              start(controller) {
                controller.error(new DOMException("Timed out", "TimeoutError"));
              },
            }),
          ),
        )
      ),
    )
  );
  assertChatAPIError(error, "provider_timeout", 504);
});

function dependencies(
  fetch: OpenRouterClientDependencies["fetch"],
): OpenRouterClientDependencies {
  return { apiKey: "test-api-key", fetch, timeoutMilliseconds: 1_000 };
}

function successResponse(): Response {
  return Response.json({
    id: "gen_123",
    choices: [{
      finish_reason: "stop",
      message: { role: "assistant", content: "Hello world" },
    }],
  });
}
