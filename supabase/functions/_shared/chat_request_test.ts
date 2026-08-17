import { maximumInputBytes, parseChatRequest } from "./chat_request.ts";
import {
  assertChatAPIError,
  assertEquals,
  captureError,
} from "./test_helpers.ts";

Deno.test("parses a valid request and ignores unknown fields", () => {
  const request = parseChatRequest({
    provider: "openai",
    model: "gpt-5.6-luna",
    input: " Hello ",
    continuation_id: "resp_123",
    unknown: true,
  });

  assertEquals(request, {
    provider: "openai",
    model: "gpt-5.6-luna",
    input: " Hello ",
    continuationId: "resp_123",
  });
});

Deno.test("omits an absent continuation", () => {
  const request = parseChatRequest({
    provider: "openai",
    model: "gpt-5.6-luna",
    input: "Hello",
  });

  assertEquals(request, {
    provider: "openai",
    model: "gpt-5.6-luna",
    input: "Hello",
  });
});

for (
  const [name, body] of [
    ["non-object body", []],
    ["missing provider", { model: "gpt-5.6-luna", input: "Hello" }],
    ["whitespace provider", {
      provider: " openai ",
      model: "gpt-5.6-luna",
      input: "Hello",
    }],
    ["whitespace input", {
      provider: "openai",
      model: "gpt-5.6-luna",
      input: "   ",
    }],
    ["invalid continuation", {
      provider: "openai",
      model: "gpt-5.6-luna",
      input: "Hello",
      continuation_id: null,
    }],
  ] as const
) {
  Deno.test(`rejects ${name}`, async () => {
    const error = await captureError(() => parseChatRequest(body));
    assertChatAPIError(error, "invalid_request", 400);
  });
}

Deno.test("accepts input at the size limit", () => {
  const input = "a".repeat(maximumInputBytes);
  const request = parseChatRequest({
    provider: "openai",
    model: "gpt-5.6-luna",
    input,
  });
  assertEquals(request.input, input);
});

Deno.test("rejects input over the size limit", async () => {
  const error = await captureError(() =>
    parseChatRequest({
      provider: "openai",
      model: "gpt-5.6-luna",
      input: "a".repeat(maximumInputBytes + 1),
    })
  );
  assertChatAPIError(error, "input_too_large", 413);
});
