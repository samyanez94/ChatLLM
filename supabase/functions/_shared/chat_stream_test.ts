import { handleChatRequest } from "./chat_handler.ts";
import { createOpenRouterStream } from "./providers/openrouter_stream.ts";
import { assert, assertEquals } from "./test_helpers.ts";

const payload = {
  provider: "openai",
  model: "gpt-6-astra",
  messages: [{ role: "user", content: "Hello" }],
  stream: true,
};
const frame = (text: string) =>
  `data: ${JSON.stringify({ choices: [{ delta: { content: text } }] })}\n\n`;
const done = "data: [DONE]\n\n";
const sse = (text: string) =>
  new Response(text, { headers: { "Content-Type": "text/event-stream" } });

function request(body: unknown = payload, signal?: AbortSignal): Request {
  return new Request("https://example.com/chat", {
    method: "POST",
    body: JSON.stringify(body),
    signal,
  });
}
function respond(
  upstream: Response,
  options: { body?: unknown; signal?: AbortSignal; timeout?: number } = {},
) {
  return handleChatRequest(
    request(options.body ?? payload, options.signal),
    undefined,
    (chat, signal) =>
      createOpenRouterStream(chat, signal, {
        apiKey: "test-key",
        timeoutMilliseconds: options.timeout ?? 10_000,
        fetch: (_url, init) => {
          const body = JSON.parse(String(init?.body));
          assertEquals(body.stream, true);
          assertEquals(body.reasoning, { effort: "low" });
          assertEquals(body.messages, payload.messages);
          assert(!("continuation_id" in body));
          return Promise.resolve(upstream);
        },
      }),
  );
}

Deno.test("streaming emits text before upstream finishes, then exactly one completion", async () => {
  let source!: ReadableStreamDefaultController<Uint8Array>;
  const encoder = new TextEncoder();
  const upstream = new Response(
    new ReadableStream<Uint8Array>({
      start(c) {
        source = c;
      },
    }),
    { headers: { "Content-Type": "text/event-stream" } },
  );
  const response = await respond(upstream);
  assertEquals(response.status, 200);
  assert(response.headers.get("content-type")!.startsWith("text/event-stream"));
  assert(Boolean(response.headers.get("X-Request-Id")));
  const reader = response.body!.getReader();
  source.enqueue(encoder.encode(frame("Hello")));
  assertEquals(
    new TextDecoder().decode((await reader.read()).value),
    'event: delta\ndata: {"text":"Hello"}\n\n',
  );
  source.enqueue(
    encoder.encode(
      'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{}}\n\n' +
        done,
    ),
  );
  const end = new TextDecoder().decode((await reader.read()).value);
  assertEquals(
    end,
    'event: completed\ndata: {"provider":"openai","model":"gpt-6-astra"}\n\n',
  );
  assertEquals((await reader.read()).done, true);
});

Deno.test("SSE parser handles one-byte UTF-8 fragments, CRLF, comments and multiline data", async () => {
  const text =
    ': heartbeat\r\nid: ignored\r\n\r\ndata: {"choices":\r\ndata: [{"delta":{"content":"Hi 🌎"}}]}\r\n\r\ndata: {"choices":[],"usage":{}}\r\n\r\n' +
    done.replaceAll("\n", "\r");
  const bytes = new TextEncoder().encode(text);
  let index = 0;
  const upstream = new Response(
    new ReadableStream<Uint8Array>({
      pull(c) {
        if (index < bytes.length) c.enqueue(bytes.slice(index, ++index));
        else c.close();
      },
    }),
    { headers: { "Content-Type": "text/event-stream; charset=utf-8" } },
  );
  const result = await (await respond(upstream)).text();
  assert(result.includes('"text":"Hi 🌎"'));
  assert(result.includes("event: completed"));
  assert(!result.includes("heartbeat"));
});

for (
  const [name, text] of [
    ["premature EOF", frame("partial")],
    [
      "finish reason without DONE",
      frame("partial") +
      'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n',
    ],
    ["empty completion", done],
    ["whitespace-only completion", frame(" ") + done],
    ["malformed JSON", "data: {bad}\n\n" + done],
    [
      "upstream error",
      frame("partial") +
      'data: {"error":{"message":"private upstream secret"}}\n\n',
    ],
    [
      "error finish reason",
      'data: {"choices":[{"delta":{},"finish_reason":"error"}]}\n\n',
    ],
    ["invalid content", 'data: {"choices":[{"delta":{"content":42}}]}\n\n'],
    ["oversized frame", "data: " + "x".repeat(1_048_577)],
  ]
) {
  Deno.test(`streaming reports a safe terminal error for ${name}`, async () => {
    const response = await respond(sse(text));
    const result = await response.text();
    assertEquals(response.status, 200);
    assert(result.includes("event: error"));
    assert(!result.includes("event: completed"));
    assert(!result.includes("private upstream secret"));
    assert(result.includes(response.headers.get("X-Request-Id")!));
  });
}

for (const status of [401, 402, 429, 503, 504]) {
  Deno.test(`streaming preserves JSON errors before streaming for upstream ${status}`, async () => {
    const response = await respond(
      Response.json({ secret: "private" }, { status }),
    );
    assertEquals(
      response.status,
      status === 401 || status === 402 ? 503 : status,
    );
    assert(response.headers.get("content-type")!.includes("application/json"));
    const body = await response.json();
    assert(Boolean(body.error.request_id));
    assert(!JSON.stringify(body).includes("private"));
  });
}

Deno.test("rejects successful non-SSE upstream responses before streaming", async () => {
  const response = await respond(Response.json({ error: "private" }));
  assertEquals(response.status, 502);
});

for (const stream of [null, "true", 1, {}]) {
  Deno.test(`rejects invalid stream flag ${JSON.stringify(stream)} before upstream`, async () => {
    let called = false;
    const response = await handleChatRequest(
      request({ ...payload, stream }),
      undefined,
      () => {
        called = true;
        throw new Error("must not call");
      },
    );
    assertEquals(response.status, 400);
    assertEquals(called, false);
  });
}

Deno.test("explicit stream false retains the complete JSON contract", async () => {
  const response = await handleChatRequest(
    request({ ...payload, stream: false }),
    () => Promise.resolve({ outputText: "Hello" }),
    () => {
      throw new Error("must not stream");
    },
  );
  assertEquals(await response.json(), {
    provider: payload.provider,
    model: payload.model,
    output_text: "Hello",
  });
});

for (const mode of ["body", "request", "timeout"] as const) {
  Deno.test(`${mode} cancellation releases a pending upstream read`, async () => {
    let cancelled = false;
    let upstreamSignal: AbortSignal | undefined;
    const abort = new AbortController();
    const upstream = new Response(
      new ReadableStream<Uint8Array>({
        cancel() {
          cancelled = true;
        },
      }),
      { headers: { "Content-Type": "text/event-stream" } },
    );
    const response = await handleChatRequest(
      request(payload, abort.signal),
      undefined,
      (chat, signal) =>
        createOpenRouterStream(chat, signal, {
          apiKey: "test",
          timeoutMilliseconds: mode === "timeout" ? 20 : 10_000,
          fetch: (_url, init) => {
            upstreamSignal = init?.signal as AbortSignal;
            return Promise.resolve(upstream);
          },
        }),
    );
    const reader = response.body!.getReader();
    const pending = reader.read();
    if (mode === "body") await reader.cancel();
    if (mode === "request") abort.abort();
    const result = await pending;
    if (mode === "timeout") {
      assert(
        new TextDecoder().decode(result.value).includes("provider_timeout"),
      );
    }
    if (mode !== "body") assertEquals((await reader.read()).done, true);
    assertEquals(cancelled, true);
    assertEquals(upstreamSignal?.aborted, true);
  });
}

for (
  const body of [
    { ...payload, provider: "unknown" },
    { ...payload, model: "unknown" },
  ]
) {
  Deno.test(`streaming validates ${body.provider}/${body.model} before fetching`, async () => {
    let called = false;
    const response = await handleChatRequest(
      request(body),
      undefined,
      (chat, signal) =>
        createOpenRouterStream(chat, signal, {
          apiKey: "test",
          timeoutMilliseconds: 1000,
          fetch: () => {
            called = true;
            return Promise.resolve(sse(done));
          },
        }),
    );
    assertEquals(response.status, 422);
    assertEquals(called, false);
  });
}

Deno.test("streaming rejects missing configuration before fetching", async () => {
  let called = false;
  const response = await handleChatRequest(
    request(),
    undefined,
    (chat, signal) =>
      createOpenRouterStream(chat, signal, {
        apiKey: undefined,
        timeoutMilliseconds: 1000,
        fetch: () => {
          called = true;
          return Promise.resolve(sse(done));
        },
      }),
  );
  assertEquals(response.status, 500);
  assertEquals(called, false);
});

Deno.test("streaming header timeout returns JSON and aborts upstream", async () => {
  const response = await handleChatRequest(
    request(),
    undefined,
    (chat, signal) =>
      createOpenRouterStream(chat, signal, {
        apiKey: "test",
        timeoutMilliseconds: 20,
        fetch: (_url, init) =>
          new Promise((_resolve, reject) => {
            init!.signal!.addEventListener(
              "abort",
              () => reject(init!.signal!.reason),
              { once: true },
            );
          }),
      }),
  );
  assertEquals(response.status, 504);
  assertEquals((await response.json()).error.code, "provider_timeout");
});

Deno.test("upstream read failures after a delta are sanitized", async () => {
  let source!: ReadableStreamDefaultController<Uint8Array>;
  const response = await respond(
    new Response(
      new ReadableStream<Uint8Array>({
        start(c) {
          source = c;
        },
      }),
      { headers: { "Content-Type": "text/event-stream" } },
    ),
  );
  const reader = response.body!.getReader();
  source.enqueue(new TextEncoder().encode(frame("partial")));
  await reader.read();
  source.error(new Error("private failure"));
  const result = new TextDecoder().decode((await reader.read()).value);
  assert(result.includes("event: error"));
  assert(!result.includes("private failure"));
  assertEquals((await reader.read()).done, true);
});
