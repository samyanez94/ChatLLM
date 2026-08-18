import type { ChatRequest } from "../chat_request.ts";
import {
  createGoogleResponse,
  type GoogleClientDependencies,
} from "./google.ts";
import {
  assertChatAPIError,
  assertEquals,
  captureError,
} from "../test_helpers.ts";

const request: ChatRequest = {
  provider: "google",
  model: "gemini-3.6-flash",
  messages: [
    { role: "user", content: "Hello" },
    { role: "assistant", content: "Hi" },
    { role: "user", content: "Continue" },
  ],
};

Deno.test("creates a Gemini interaction and parses its response", async () => {
  let capturedInput: string | URL | Request | undefined;
  let capturedInit: RequestInit | undefined;
  const response = await createGoogleResponse(
    request,
    "request-123",
    dependencies((input, init) => {
      capturedInput = input;
      capturedInit = init;
      return Promise.resolve(successResponse());
    }),
  );

  assertEquals(
    capturedInput,
    "https://generativelanguage.googleapis.com/v1/interactions",
  );
  assertEquals(new Headers(capturedInit?.headers).get("x-goog-api-key"), "key");
  assertEquals(
    new Headers(capturedInit?.headers).get("X-Client-Request-Id"),
    "request-123",
  );
  assertEquals(JSON.parse(String(capturedInit?.body)), {
    model: "gemini-3.6-flash",
    input: [
      {
        type: "user_input",
        content: [{ type: "text", text: "Hello" }],
      },
      {
        type: "model_output",
        content: [{ type: "text", text: "Hi" }],
      },
      {
        type: "user_input",
        content: [{ type: "text", text: "Continue" }],
      },
    ],
  });
  assertEquals(response, { id: "interaction-1", outputText: "Hello world" });

  await createGoogleResponse(
    { ...request, continuationId: "interaction-1" },
    "request-456",
    dependencies((_input, init) => {
      capturedInit = init;
      return Promise.resolve(successResponse());
    }),
  );
  assertEquals(JSON.parse(String(capturedInit?.body)), {
    model: "gemini-3.6-flash",
    input: "Continue",
    previous_interaction_id: "interaction-1",
  });
});

Deno.test("rejects missing Gemini configuration", async () => {
  const error = await captureError(() =>
    createGoogleResponse(
      request,
      "request-123",
      {
        apiKey: undefined,
        fetch: () => Promise.resolve(successResponse()),
        timeoutMilliseconds: 1_000,
      },
    )
  );
  assertChatAPIError(error, "internal_error", 500);
});

Deno.test("translates a Gemini upstream failure", async () => {
  const error = await captureError(() =>
    createGoogleResponse(
      request,
      "request-123",
      dependencies(() => Promise.resolve(new Response(null, { status: 500 }))),
    )
  );
  assertChatAPIError(error, "provider_error", 502);
});

function dependencies(
  fetch: GoogleClientDependencies["fetch"],
  apiKey: string | undefined = "key",
): GoogleClientDependencies {
  return { apiKey, fetch, timeoutMilliseconds: 1_000 };
}

function successResponse(): Response {
  return Response.json({
    id: "interaction-1",
    status: "completed",
    steps: [{
      type: "model_output",
      content: [
        { type: "text", text: "Hello " },
        { type: "text", text: "world" },
      ],
    }],
  });
}
