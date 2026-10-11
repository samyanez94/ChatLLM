import type { ChatRequest } from "../chat_request.ts";
import { ChatAPIError } from "../errors.ts";
import { resolveOpenRouterModel } from "../models.ts";
import {
  errorForStatus,
  type OpenRouterClientDependencies,
} from "./openrouter.ts";

/** Opens upstream eagerly, so connection failures retain normal HTTP errors. */
export async function createOpenRouterStream(
  request: ChatRequest,
  signal: AbortSignal,
  dependencies: OpenRouterClientDependencies = {
    apiKey: Deno.env.get("OPENROUTER_API_KEY"),
    fetch,
    timeoutMilliseconds: 60_000,
  },
): Promise<AsyncGenerator<string>> {
  const model = resolveOpenRouterModel(request.provider, request.model);
  if (!dependencies.apiKey?.trim()) {
    throw new ChatAPIError(
      "internal_error",
      "The chat service is not configured.",
    );
  }
  const upstreamSignal = AbortSignal.any([
    signal,
    AbortSignal.timeout(dependencies.timeoutMilliseconds),
  ]);
  try {
    const response = await dependencies.fetch(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${dependencies.apiKey}`,
          "Content-Type": "application/json",
          Accept: "text/event-stream",
        },
        body: JSON.stringify({
          model,
          messages: request.messages,
          stream: true,
          ...(model === "openai/gpt-6-astra"
            ? { reasoning: { effort: "low" } }
            : {}),
        }),
        signal: upstreamSignal,
      },
    );
    if (!response.ok) {
      await response.body?.cancel();
      throw errorForStatus(response.status);
    }
    if (
      !response.body ||
      response.headers.get("content-type")?.split(";")[0].trim()
          .toLowerCase() !==
        "text/event-stream"
    ) {
      await response.body?.cancel();
      throw invalidStream();
    }
    return readText(response.body, upstreamSignal);
  } catch (error) {
    throw streamError(error, upstreamSignal);
  }
}

async function* readText(
  body: ReadableStream<Uint8Array>,
  signal: AbortSignal,
): AsyncGenerator<string> {
  let hasText = false;
  try {
    for await (const data of readEvents(body, signal)) {
      if (data === "[DONE]") {
        if (!hasText) throw invalidStream();
        return;
      }
      const chunk: unknown = JSON.parse(data);
      if (
        !isRecord(chunk) || "error" in chunk || !Array.isArray(chunk.choices)
      ) {
        throw invalidStream();
      }
      // Usage-only frames and role/reasoning-only deltas contain no visible text.
      if (chunk.choices.length === 0) continue;
      const choice = chunk.choices[0];
      if (
        !isRecord(choice) || choice.finish_reason === "error" ||
        !isRecord(choice.delta)
      ) {
        throw invalidStream();
      }
      const content = choice.delta.content;
      if (content === undefined || content === null || content === "") continue;
      if (typeof content !== "string") throw invalidStream();
      hasText ||= content.trim().length > 0;
      yield content;
    }
    // A finish_reason alone cannot distinguish a complete stream from a dropped connection.
    throw invalidStream();
  } catch (error) {
    throw streamError(error, signal);
  }
}

/** SSE framing with incremental UTF-8 decoding, CR/LF handling and bounded frames. */
async function* readEvents(
  body: ReadableStream<Uint8Array>,
  signal: AbortSignal,
): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  const cancel = () => {
    void reader.cancel(signal.reason).catch(() => {});
  };
  signal.addEventListener("abort", cancel, { once: true });
  let line = "";
  let data: string[] = [];
  let frameSize = 0;
  let afterCR = false;
  try {
    signal.throwIfAborted();
    while (true) {
      const result = await reader.read();
      signal.throwIfAborted();
      const text = result.done
        ? decoder.decode()
        : decoder.decode(result.value, { stream: true });
      for (const character of text) {
        if (afterCR && character === "\n") {
          afterCR = false;
          continue;
        }
        afterCR = character === "\r";
        if (character !== "\r" && character !== "\n") {
          line += character;
          if (++frameSize > 1_048_576) throw invalidStream();
          continue;
        }
        if (line === "") {
          if (data.length) yield data.join("\n");
          data = [];
          frameSize = 0;
        } else if (line === "data" || line.startsWith("data:")) {
          data.push(line.slice(5).replace(/^ /, ""));
        }
        line = "";
      }
      if (result.done) return;
    }
  } finally {
    signal.removeEventListener("abort", cancel);
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

function invalidStream(): ChatAPIError {
  return new ChatAPIError(
    "provider_error",
    "The provider returned an invalid or incomplete stream.",
  );
}

function streamError(error: unknown, signal: AbortSignal): Error {
  if (
    signal.aborted && signal.reason instanceof DOMException &&
    signal.reason.name === "TimeoutError"
  ) {
    return new ChatAPIError(
      "provider_timeout",
      "The provider did not respond in time.",
    );
  }
  if (signal.aborted) return signal.reason;
  if (error instanceof ChatAPIError) return error;
  return invalidStream();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
