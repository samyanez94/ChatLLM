import type { ChatRequest } from "../chat_request.ts";
import {
  createOpenAIResponse,
  type OpenAIClientDependencies,
} from "./openai.ts";
import {
  assert,
  assertChatAPIError,
  assertEquals,
  captureError,
} from "../test_helpers.ts";

const request: ChatRequest = {
  provider: "openai",
  model: "gpt-5.6-luna",
  input: "Hello",
};

Deno.test("creates an OpenAI response request", async () => {
  let capturedInput: string | URL | Request | undefined;
  let capturedInit: RequestInit | undefined;
  const response = await createOpenAIResponse(
    { ...request, continuationId: "resp_previous" },
    "request-123",
    dependencies((input, init) => {
      capturedInput = input;
      capturedInit = init;
      return Promise.resolve(openAISuccessResponse());
    }),
  );

  assertEquals(capturedInput, "https://api.openai.com/v1/responses");
  assertEquals(capturedInit?.method, "POST");
  const headers = new Headers(capturedInit?.headers);
  assertEquals(headers.get("Authorization"), "Bearer test-api-key");
  assertEquals(headers.get("X-Client-Request-Id"), "request-123");
  assertEquals(JSON.parse(String(capturedInit?.body)), {
    model: "gpt-5.6-luna",
    input: "Hello",
    previous_response_id: "resp_previous",
  });
  assert(capturedInit?.signal instanceof AbortSignal);
  assertEquals(response, { id: "resp_123", outputText: "Hello world" });
});

Deno.test("omits previous_response_id without a continuation", async () => {
  let capturedBody: unknown;
  await createOpenAIResponse(
    request,
    "request-123",
    dependencies((_input, init) => {
      capturedBody = JSON.parse(String(init?.body));
      return Promise.resolve(openAISuccessResponse());
    }),
  );

  assertEquals(capturedBody, {
    model: "gpt-5.6-luna",
    input: "Hello",
  });
});

Deno.test("combines output text content", async () => {
  const response = await createOpenAIResponse(
    request,
    "request-123",
    dependencies(() =>
      Promise.resolve(Response.json({
        id: "resp_123",
        output: [
          { content: [{ type: "output_text", text: "Hello " }] },
          { content: [{ type: "output_text", text: "world" }] },
        ],
      }))
    ),
  );
  assertEquals(response.outputText, "Hello world");
});

for (
  const [name, status, continuationId, expectedCode, expectedStatus] of [
    ["rate limits", 429, undefined, "rate_limited", 429],
    ["provider errors", 500, undefined, "provider_error", 502],
    ["invalid continuations", 400, "resp_invalid", "invalid_continuation", 422],
  ] as const
) {
  Deno.test(`translates ${name}`, async () => {
    const error = await captureError(() =>
      createOpenAIResponse(
        { ...request, continuationId },
        "request-123",
        dependencies(() => Promise.resolve(new Response(null, { status }))),
      )
    );
    assertChatAPIError(error, expectedCode, expectedStatus);
  });
}

Deno.test("rejects an invalid provider response", async () => {
  const error = await captureError(() =>
    createOpenAIResponse(
      request,
      "request-123",
      dependencies(() =>
        Promise.resolve(Response.json({ id: "resp_123", output: [] }))
      ),
    )
  );
  assertChatAPIError(error, "provider_error", 502);
});

Deno.test("rejects missing server configuration", async () => {
  const error = await captureError(() =>
    createOpenAIResponse(
      request,
      "request-123",
      {
        apiKey: undefined,
        fetch: () => Promise.resolve(openAISuccessResponse()),
        timeoutMilliseconds: 1_000,
      },
    )
  );
  assertChatAPIError(error, "internal_error", 500);
});

Deno.test("translates network failures", async () => {
  const error = await captureError(() =>
    createOpenAIResponse(
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
    createOpenAIResponse(
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
  fetch: OpenAIClientDependencies["fetch"],
  apiKey: string | undefined = "test-api-key",
): OpenAIClientDependencies {
  return {
    apiKey,
    fetch,
    timeoutMilliseconds: 1_000,
  };
}

function openAISuccessResponse(): Response {
  return Response.json({
    id: "resp_123",
    output: [{
      content: [{ type: "output_text", text: "Hello world" }],
    }],
  });
}
