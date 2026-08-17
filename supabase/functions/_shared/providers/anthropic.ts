import type { ChatRequest } from "../chat_request.ts";
import { ChatAPIError } from "../errors.ts";

const messagesURL = "https://api.anthropic.com/v1/messages";
const anthropicVersion = "2023-06-01";
const maximumOutputTokens = 8_192;
const requestTimeoutMilliseconds = 60_000;

type Fetch = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface AnthropicClientDependencies {
  apiKey: string | undefined;
  fetch: Fetch;
  timeoutMilliseconds: number;
}

export interface AnthropicResponse {
  outputText: string;
}

/** Creates a response using Anthropic's Messages API. */
export async function createAnthropicResponse(
  request: ChatRequest,
  requestId: string,
  dependencies: AnthropicClientDependencies = {
    apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
    fetch,
    timeoutMilliseconds: requestTimeoutMilliseconds,
  },
): Promise<AnthropicResponse> {
  if (!dependencies.apiKey) {
    throw new ChatAPIError(
      "internal_error",
      "The chat service is not configured.",
    );
  }

  let response: Response;
  try {
    response = await dependencies.fetch(messagesURL, {
      method: "POST",
      headers: {
        "anthropic-version": anthropicVersion,
        "Content-Type": "application/json",
        "x-api-key": dependencies.apiKey,
        "X-Request-Id": requestId,
      },
      body: JSON.stringify({
        model: request.model,
        max_tokens: maximumOutputTokens,
        messages: request.messages,
      }),
      signal: AbortSignal.timeout(dependencies.timeoutMilliseconds),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new ChatAPIError(
        "provider_timeout",
        "The provider did not respond in time.",
      );
    }
    throw new ChatAPIError(
      "service_unavailable",
      "The provider is temporarily unavailable.",
    );
  }

  if (!response.ok) {
    if (response.status === 429) {
      throw new ChatAPIError(
        "rate_limited",
        "The provider rate limit has been exceeded.",
      );
    }
    throw new ChatAPIError(
      "provider_error",
      "The provider could not complete the request.",
    );
  }

  const responseBody: unknown = await response.json().catch(() => undefined);
  const parsedResponse = parseAnthropicResponse(responseBody);
  if (!parsedResponse) {
    throw new ChatAPIError(
      "provider_error",
      "The provider returned an invalid response.",
    );
  }
  return parsedResponse;
}

function parseAnthropicResponse(
  value: unknown,
): AnthropicResponse | undefined {
  if (!isRecord(value) || !Array.isArray(value.content)) {
    return undefined;
  }
  const outputText = value.content
    .filter((item) => isRecord(item) && item.type === "text")
    .map((item) =>
      isRecord(item) && typeof item.text === "string" ? item.text : ""
    )
    .join("");
  return outputText.length === 0 ? undefined : { outputText };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
