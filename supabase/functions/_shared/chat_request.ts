import { ChatAPIError } from "./errors.ts";

export const maximumInputBytes = 32 * 1024;

export type ChatMessageRole = "user" | "assistant";

export interface ChatMessage {
  role: ChatMessageRole;
  content: string;
}

export interface ChatRequest {
  provider: string;
  model: string;
  messages: ChatMessage[];
  continuationId?: string;
}

/** Decodes and validates the provider-neutral Chat API request body. */
export function parseChatRequest(value: unknown): ChatRequest {
  if (!isRecord(value)) {
    throw invalidRequest("The request body must be a JSON object.");
  }

  const provider = requiredNonEmptyString(value, "provider");
  const model = requiredNonEmptyString(value, "model");
  const messages = requiredMessages(value.messages);
  const continuationId = optionalNonEmptyString(value, "continuation_id");

  const inputBytes = messages.reduce(
    (total, message) =>
      total + new TextEncoder().encode(message.content).byteLength,
    0,
  );
  if (inputBytes > maximumInputBytes) {
    throw new ChatAPIError(
      "input_too_large",
      `Message content must not exceed ${maximumInputBytes} UTF-8 bytes.`,
    );
  }

  return {
    provider,
    model,
    messages,
    ...(continuationId === undefined ? {} : { continuationId }),
  };
}

function requiredMessages(value: unknown): ChatMessage[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw invalidRequest("Field 'messages' must be a non-empty array.");
  }

  const messages = value.map((message, index) => {
    if (!isRecord(message)) {
      throw invalidRequest(`Message at index ${index} must be an object.`);
    }
    if (message.role !== "user" && message.role !== "assistant") {
      throw invalidRequest(
        `Message at index ${index} must have role 'user' or 'assistant'.`,
      );
    }
    const role: ChatMessageRole = message.role;
    const content = requiredNonEmptyString(message, "content", true);
    return { role, content };
  });

  if (messages.at(-1)?.role !== "user") {
    throw invalidRequest("The final message must have role 'user'.");
  }
  return messages;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requiredNonEmptyString(
  value: Record<string, unknown>,
  field: string,
  allowSurroundingWhitespace = false,
): string {
  const fieldValue = value[field];
  if (
    typeof fieldValue !== "string" ||
    fieldValue.trim().length === 0 ||
    (!allowSurroundingWhitespace && fieldValue !== fieldValue.trim())
  ) {
    throw invalidRequest(`Field '${field}' must be a non-empty string.`);
  }
  return fieldValue;
}

function optionalNonEmptyString(
  value: Record<string, unknown>,
  field: string,
): string | undefined {
  const fieldValue = value[field];
  if (fieldValue === undefined) {
    return undefined;
  }
  if (
    typeof fieldValue !== "string" ||
    fieldValue.trim().length === 0 ||
    fieldValue !== fieldValue.trim()
  ) {
    throw invalidRequest(`Field '${field}' must be a non-empty string.`);
  }
  return fieldValue;
}

function invalidRequest(message: string): ChatAPIError {
  return new ChatAPIError("invalid_request", message);
}
