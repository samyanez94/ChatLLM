import type { ChatMessage, ChatRequest } from "../chat_request.ts";
import { ChatAPIError } from "../errors.ts";

const interactionsURL =
  "https://generativelanguage.googleapis.com/v1/interactions";
const requestTimeoutMilliseconds = 60_000;

type Fetch = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface GoogleClientDependencies {
  apiKey: string | undefined;
  fetch: Fetch;
  timeoutMilliseconds: number;
}

export interface GoogleResponse {
  id: string;
  outputText: string;
}

/** Creates a response using Google's Gemini Interactions API. */
export async function createGoogleResponse(
  request: ChatRequest,
  requestId: string,
  dependencies: GoogleClientDependencies = {
    apiKey: Deno.env.get("GEMINI_API_KEY"),
    fetch,
    timeoutMilliseconds: requestTimeoutMilliseconds,
  },
): Promise<GoogleResponse> {
  if (!dependencies.apiKey) {
    throw new ChatAPIError(
      "internal_error",
      "The chat service is not configured.",
    );
  }

  let response: Response;
  try {
    response = await dependencies.fetch(interactionsURL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Client-Request-Id": requestId,
        "x-goog-api-key": dependencies.apiKey,
      },
      body: JSON.stringify({
        model: request.model,
        input: request.continuationId === undefined
          ? request.messages.map(interactionStep)
          : request.messages.at(-1)?.content,
        ...(request.continuationId === undefined ? {} : {
          previous_interaction_id: request.continuationId,
        }),
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
  const parsedResponse = parseGoogleResponse(responseBody);
  if (!parsedResponse) {
    throw new ChatAPIError(
      "provider_error",
      "The provider returned an invalid response.",
    );
  }
  return parsedResponse;
}

function interactionStep(message: ChatMessage): Record<string, unknown> {
  return {
    type: message.role === "user" ? "user_input" : "model_output",
    content: [{ type: "text", text: message.content }],
  };
}

function parseGoogleResponse(value: unknown): GoogleResponse | undefined {
  if (
    !isRecord(value) ||
    typeof value.id !== "string" ||
    value.id.length === 0 ||
    value.status !== "completed" ||
    !Array.isArray(value.steps)
  ) {
    return undefined;
  }

  const outputText = value.steps
    .filter((step) => isRecord(step) && step.type === "model_output")
    .flatMap((step) =>
      isRecord(step) && Array.isArray(step.content) ? step.content : []
    )
    .filter((content) => isRecord(content) && content.type === "text")
    .map((content) =>
      isRecord(content) && typeof content.text === "string" ? content.text : ""
    )
    .join("");

  return outputText.length === 0 ? undefined : { id: value.id, outputText };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
