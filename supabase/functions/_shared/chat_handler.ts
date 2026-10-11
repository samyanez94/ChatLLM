import { parseChatRequest } from "./chat_request.ts";
import type { ChatResponse } from "./chat_response.ts";
import { ChatAPIError, makeErrorResponse } from "./errors.ts";
import { createOpenRouterStream } from "./providers/openrouter_stream.ts";
import { createOpenRouterResponse } from "./providers/openrouter.ts";

type CreateResponse = (
  request: ReturnType<typeof parseChatRequest>,
) => ReturnType<typeof createOpenRouterResponse>;

/** Handles the public chat contract after Supabase authenticates the request. */
export async function handleChatRequest(
  request: Request,
  createResponse: CreateResponse = createOpenRouterResponse,
  createStream: typeof createOpenRouterStream = createOpenRouterStream,
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
    if (chatRequest.stream) {
      const cancellation = new AbortController();
      const signal = AbortSignal.any([request.signal, cancellation.signal]);
      const upstream = await createStream(chatRequest, signal);
      const encoder = new TextEncoder();
      let cancelled = false;
      const encodeEvent = (event: string, data: unknown) =>
        encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
      const body = new ReadableStream<Uint8Array>({
        async pull(controller) {
          try {
            const next = await upstream.next();
            if (cancelled) return;
            signal.throwIfAborted();
            if (next.done) {
              controller.enqueue(encodeEvent("completed", {
                provider: chatRequest.provider,
                model: chatRequest.model,
              }));
              controller.close();
            } else {
              controller.enqueue(encodeEvent("delta", { text: next.value }));
            }
          } catch (error) {
            if (cancelled) return;
            const safeError = error instanceof ChatAPIError
              ? error
              : new ChatAPIError(
                "provider_error",
                "The response stream was interrupted.",
              );
            controller.enqueue(encodeEvent("error", {
              error: {
                code: safeError.code,
                message: safeError.message,
                request_id: requestId,
              },
            }));
            controller.close();
            cancellation.abort();
            await upstream.return(undefined);
          }
        },
        async cancel() {
          cancelled = true;
          cancellation.abort();
          await upstream.return(undefined);
        },
      });
      return new Response(body, {
        headers: {
          "Content-Type": "text/event-stream; charset=utf-8",
          "Cache-Control": "no-cache, no-transform",
          "X-Request-Id": requestId,
        },
      });
    }
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
