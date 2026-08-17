import type { ChatRequest } from "../chat_request.ts";
import { ChatAPIError } from "../errors.ts";

const responsesURL = "https://api.openai.com/v1/responses";
const requestTimeoutMilliseconds = 60_000;

type Fetch = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface OpenAIClientDependencies {
  apiKey: string | undefined;
  fetch: Fetch;
  timeoutMilliseconds: number;
}

export interface OpenAIResponse {
  id: string;
  outputText: string;
}

/** Creates a response using OpenAI's Responses API. */
export async function createOpenAIResponse(
  request: ChatRequest,
  requestId: string,
  dependencies: OpenAIClientDependencies = {
    apiKey: Deno.env.get("OPENAI_API_KEY"),
    fetch,
    timeoutMilliseconds: requestTimeoutMilliseconds,
  },
): Promise<OpenAIResponse> {
  const apiKey = dependencies.apiKey;
  if (!apiKey) {
    throw new ChatAPIError(
      "internal_error",
      "The chat service is not configured.",
    );
  }

  let response: Response;
  try {
    response = await dependencies.fetch(responsesURL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "X-Client-Request-Id": requestId,
      },
      body: JSON.stringify({
        model: request.model,
        input: request.input,
        ...(request.continuationId === undefined
          ? {}
          : { previous_response_id: request.continuationId }),
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
    if (
      request.continuationId !== undefined &&
      (response.status === 400 || response.status === 404)
    ) {
      throw new ChatAPIError(
        "invalid_continuation",
        "The continuation cannot be used with this request.",
      );
    }
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
  const parsedResponse = parseOpenAIResponse(responseBody);
  if (!parsedResponse) {
    throw new ChatAPIError(
      "provider_error",
      "The provider returned an invalid response.",
    );
  }
  return parsedResponse;
}

function parseOpenAIResponse(value: unknown): OpenAIResponse | undefined {
  if (!isRecord(value) || typeof value.id !== "string") {
    return undefined;
  }

  const outputText = Array.isArray(value.output)
    ? value.output
      .flatMap((item) =>
        isRecord(item) && Array.isArray(item.content) ? item.content : []
      )
      .filter((item) => isRecord(item) && item.type === "output_text")
      .map((item) =>
        isRecord(item) && typeof item.text === "string" ? item.text : ""
      )
      .join("")
    : "";

  if (outputText.length === 0) {
    return undefined;
  }
  return { id: value.id, outputText };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
