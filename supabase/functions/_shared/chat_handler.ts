import { parseChatRequest } from "./chat_request.ts";
import type { ChatResponse } from "./chat_response.ts";
import { ChatAPIError, makeErrorResponse } from "./errors.ts";
import { createOpenRouterResponse } from "./providers/openrouter.ts";

type CreateResponse = (
  request: ReturnType<typeof parseChatRequest>,
) => ReturnType<typeof createOpenRouterResponse>;

/** Handles the public chat contract after Supabase authenticates the request. */
export async function handleChatRequest(
  request: Request,
  createResponse: CreateResponse = createOpenRouterResponse,
): Promise<Response> {
  const requestId = crypto.randomUUID();
  try {
    if (request.method !== "POST") {
      return makeErrorResponse(
        new ChatAPIError(
          "method_not_allowed",
          "Only POST requests are supported.",
        ),
        requestId,
        { Allow: "POST" },
      );
    }

    const chatRequest = parseChatRequest(await parseJSON(request));
    const providerResponse = await createResponse(chatRequest);
    const response: ChatResponse = {
      provider: chatRequest.provider,
      model: chatRequest.model,
      output_text: providerResponse.outputText,
    };
    return Response.json(response, {
      headers: { "X-Request-Id": requestId },
    });
  } catch (error) {
    if (error instanceof ChatAPIError) {
      return makeErrorResponse(error, requestId);
    }
    console.error("Unexpected chat request failure", { requestId });
    return makeErrorResponse(
      new ChatAPIError(
        "internal_error",
        "The chat service encountered an unexpected failure.",
      ),
      requestId,
    );
  }
}

async function parseJSON(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    throw new ChatAPIError(
      "invalid_request",
      "The request body must contain valid JSON.",
    );
  }
}
