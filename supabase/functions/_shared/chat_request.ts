import { ChatAPIError } from "./errors.ts";

export const maximumInputBytes = 32 * 1024;

export interface ChatRequest {
  provider: string;
  model: string;
  input: string;
  continuationId?: string;
}

/** Decodes and validates the provider-neutral Chat API request body. */
export function parseChatRequest(value: unknown): ChatRequest {
  if (!isRecord(value)) {
    throw invalidRequest("The request body must be a JSON object.");
  }

  const provider = requiredNonEmptyString(value, "provider");
  const model = requiredNonEmptyString(value, "model");
  const input = requiredNonEmptyString(value, "input", true);
  const continuationId = optionalNonEmptyString(value, "continuation_id");

  if (new TextEncoder().encode(input).byteLength > maximumInputBytes) {
    throw new ChatAPIError(
      "input_too_large",
      `Input must not exceed ${maximumInputBytes} UTF-8 bytes.`,
    );
  }

  return {
    provider,
    model,
    input,
    ...(continuationId === undefined ? {} : { continuationId }),
  };
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
