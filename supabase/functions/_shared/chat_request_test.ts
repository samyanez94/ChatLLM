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
    messages: [{ role: "user", content: " Hello " }],
    continuation_id: "resp_123",
    unknown: true,
  });

  assertEquals(request, {
    provider: "openai",
    model: "gpt-5.6-luna",
    messages: [{ role: "user", content: " Hello " }],
    continuationId: "resp_123",
  });
});

Deno.test("omits an absent continuation", () => {
  const request = parseChatRequest({
    provider: "openai",
    model: "gpt-5.6-luna",
    messages: [{ role: "user", content: "Hello" }],
  });

  assertEquals(request, {
    provider: "openai",
    model: "gpt-5.6-luna",
    messages: [{ role: "user", content: "Hello" }],
  });
});

for (
  const [name, body] of [
    ["non-object body", []],
    ["missing provider", {
      model: "gpt-5.6-luna",
      messages: [{ role: "user", content: "Hello" }],
    }],
    ["whitespace provider", {
      provider: " openai ",
      model: "gpt-5.6-luna",
      messages: [{ role: "user", content: "Hello" }],
    }],
    ["empty messages", {
      provider: "openai",
      model: "gpt-5.6-luna",
      messages: [],
    }],
    ["whitespace content", {
      provider: "openai",
      model: "gpt-5.6-luna",
      messages: [{ role: "user", content: "   " }],
    }],
    ["unknown message role", {
      provider: "openai",
      model: "gpt-5.6-luna",
      messages: [{ role: "system", content: "Hello" }],
    }],
    ["assistant final message", {
      provider: "openai",
      model: "gpt-5.6-luna",
      messages: [{ role: "assistant", content: "Hello" }],
    }],
    ["legacy input", {
      provider: "openai",
      model: "gpt-5.6-luna",
      input: "Hello",
    }],
    ["invalid continuation", {
      provider: "openai",
      model: "gpt-5.6-luna",
      messages: [{ role: "user", content: "Hello" }],
      continuation_id: null,
    }],
  ] as const
) {
  Deno.test(`rejects ${name}`, async () => {
    const error = await captureError(() => parseChatRequest(body));
    assertChatAPIError(error, "invalid_request", 400);
  });
}

Deno.test("accepts message content at the combined size limit", () => {
  const input = "a".repeat(maximumInputBytes);
  const request = parseChatRequest({
    provider: "openai",
    model: "gpt-5.6-luna",
    messages: [
      { role: "user", content: input.slice(0, maximumInputBytes / 2) },
      { role: "assistant", content: "Reply" },
      {
        role: "user",
        content: input.slice(maximumInputBytes / 2 + "Reply".length),
      },
    ],
  });
  assertEquals(
    request.messages.reduce(
      (total, message) => total + message.content.length,
      0,
    ),
    maximumInputBytes,
  );
});

Deno.test("rejects combined message content over the size limit", async () => {
  const error = await captureError(() =>
    parseChatRequest({
      provider: "openai",
      model: "gpt-5.6-luna",
      messages: [
        { role: "user", content: "a".repeat(maximumInputBytes) },
        { role: "assistant", content: "b" },
        { role: "user", content: "c" },
      ],
    })
  );
  assertChatAPIError(error, "input_too_large", 413);
});
