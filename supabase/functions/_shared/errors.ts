const errorStatusCodes = {
  invalid_request: 400,
  invalid_api_key: 401,
  method_not_allowed: 405,
  input_too_large: 413,
  unsupported_provider: 422,
  unsupported_model: 422,
  invalid_continuation: 422,
  rate_limited: 429,
  internal_error: 500,
  provider_error: 502,
  service_unavailable: 503,
  provider_timeout: 504,
} as const;

export type ChatAPIErrorCode = keyof typeof errorStatusCodes;

/** A failure represented by the public Chat API error contract. */
export class ChatAPIError extends Error {
  readonly code: ChatAPIErrorCode;
  readonly status: number;

  constructor(code: ChatAPIErrorCode, message: string) {
    super(message);
    this.name = "ChatAPIError";
    this.code = code;
    this.status = errorStatusCodes[code];
  }
}

/** Converts a public Chat API failure into the standard JSON error envelope. */
export function makeErrorResponse(
  error: ChatAPIError,
  requestId: string = crypto.randomUUID(),
  headers?: HeadersInit,
): Response {
  return Response.json(
    {
      error: {
        code: error.code,
        message: error.message,
        request_id: requestId,
      },
    },
    {
      status: error.status,
      headers,
    },
  );
}
