import type { ChatRequest } from "../chat_request.ts";
import { ChatAPIError } from "../errors.ts";
import { resolveOpenRouterModel } from "../models.ts";

const completionsURL = "https://openrouter.ai/api/v1/chat/completions";
const requestTimeoutMilliseconds = 60_000;

export interface OpenRouterClientDependencies {
  apiKey: string | undefined;
  fetch: (
    input: string | URL | Request,
    init?: RequestInit,
  ) => Promise<Response>;
  timeoutMilliseconds: number;
}

export interface OpenRouterResponse {
  outputText: string;
}

/** Generates a complete reply using automatic routing for the selected model. */
export async function createOpenRouterResponse(
  request: ChatRequest,
  dependencies: OpenRouterClientDependencies = {
    apiKey: Deno.env.get("OPENROUTER_API_KEY"),
    fetch,
    timeoutMilliseconds: requestTimeoutMilliseconds,
  },
): Promise<OpenRouterResponse> {
  const model = resolveOpenRouterModel(request.provider, request.model);
  const apiKey = dependencies.apiKey;
  if (!apiKey?.trim()) {
    throw new ChatAPIError(
      "internal_error",
      "The chat service is not configured.",
    );
  }

  try {
    const response = await dependencies.fetch(completionsURL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: request.messages,
        stream: false,
        ...(model === "openai/gpt-6-astra"
          ? { reasoning: { effort: "low" } }
          : {}),
      }),
      signal: AbortSignal.timeout(dependencies.timeoutMilliseconds),
    });

    if (!response.ok) {
      // Never expose upstream bodies or confuse upstream auth with app auth.
      await response.body?.cancel();
      throw errorForStatus(response.status);
    }

    const body: unknown = await response.json();
    const outputText = parseOutputText(body);
    if (outputText === undefined) {
      throw new ChatAPIError(
        "provider_error",
        "The provider returned an invalid response.",
      );
    }
    // Legacy continuation IDs are deliberately ignored. Every request carries
    // the full transcript; OpenRouter generation IDs are not continuations.
    return { outputText };
  } catch (error) {
    if (error instanceof ChatAPIError) {
      throw error;
    }
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new ChatAPIError(
        "provider_timeout",
        "The provider did not respond in time.",
      );
    }
    if (error instanceof SyntaxError) {
      throw new ChatAPIError(
        "provider_error",
        "The provider returned an invalid response.",
      );
    }
    throw new ChatAPIError(
      "service_unavailable",
      "The provider is temporarily unavailable.",
    );
  }
}

export function errorForStatus(status: number): ChatAPIError {
  switch (status) {
    case 401:
      return new ChatAPIError(
        "service_unavailable",
        "The chat service could not authenticate with its model provider.",
      );
    case 402:
      return new ChatAPIError(
        "service_unavailable",
        "The chat service's credit or spending limit has been reached. Please try again later.",
      );
    case 429:
      return new ChatAPIError(
        "rate_limited",
        "The provider rate limit has been exceeded.",
      );
    case 408:
    case 504:
      return new ChatAPIError(
        "provider_timeout",
        "The provider did not respond in time.",
      );
    case 503:
      return new ChatAPIError(
        "service_unavailable",
        "The provider is temporarily unavailable.",
      );
    default:
      return new ChatAPIError(
        "provider_error",
        "The provider could not complete the request.",
      );
  }
}

function parseOutputText(value: unknown): string | undefined {
  if (!isRecord(value) || "error" in value || !Array.isArray(value.choices)) {
    return undefined;
  }
  const choice = value.choices[0];
  if (
    !isRecord(choice) || choice.finish_reason === "error" ||
    !isRecord(choice.message)
  ) {
    return undefined;
  }
  const content = choice.message.content;
  return typeof content === "string" && content.trim().length > 0
    ? content
    : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
