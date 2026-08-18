import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { parseChatRequest } from "../_shared/chat_request.ts";
import type { ChatResponse } from "../_shared/chat_response.ts";
import { ChatAPIError, makeErrorResponse } from "../_shared/errors.ts";
import { isSupportedModel, isSupportedProvider } from "../_shared/models.ts";
import { createAnthropicResponse } from "../_shared/providers/anthropic.ts";
import { createOpenAIResponse } from "../_shared/providers/openai.ts";
import { createGoogleResponse } from "../_shared/providers/google.ts";

export default {
  fetch: withSupabase({ auth: "publishable" }, async (request) => {
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

      const requestBody = await parseJSON(request);
      const chatRequest = parseChatRequest(requestBody);

      if (!isSupportedProvider(chatRequest.provider)) {
        throw new ChatAPIError(
          "unsupported_provider",
          `Provider '${chatRequest.provider}' is not supported.`,
        );
      }
      if (!isSupportedModel(chatRequest.provider, chatRequest.model)) {
        throw new ChatAPIError(
          "unsupported_model",
          `Model '${chatRequest.model}' is not supported by provider '${chatRequest.provider}'.`,
        );
      }

      const providerResponse = await createProviderResponse(
        chatRequest,
        requestId,
      );
      const response: ChatResponse = {
        provider: chatRequest.provider,
        model: chatRequest.model,
        ...(hasContinuationId(providerResponse)
          ? { continuation_id: providerResponse.id }
          : {}),
        output_text: providerResponse.outputText,
      };
      return Response.json(response, {
        headers: { "X-Request-Id": requestId },
      });
    } catch (error) {
      if (error instanceof ChatAPIError) {
        return makeErrorResponse(error, requestId);
      }

      console.error("Unexpected chat request failure", { requestId, error });
      return makeErrorResponse(
        new ChatAPIError(
          "internal_error",
          "The chat service encountered an unexpected failure.",
        ),
        requestId,
      );
    }
  }),
};

async function createProviderResponse(
  request: ReturnType<typeof parseChatRequest>,
  requestId: string,
) {
  switch (request.provider) {
    case "openai":
      return await createOpenAIResponse(request, requestId);
    case "anthropic":
      return await createAnthropicResponse(request, requestId);
    case "google":
      return await createGoogleResponse(request, requestId);
    default:
      throw new ChatAPIError(
        "unsupported_provider",
        `Provider '${request.provider}' is not supported.`,
      );
  }
}

function hasContinuationId(
  response: { outputText: string } | { id: string; outputText: string },
): response is { id: string; outputText: string } {
  return "id" in response;
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
