import { ChatAPIError, makeErrorResponse } from "./errors.ts";
import { assertEquals } from "./test_helpers.ts";

Deno.test("creates the standard error envelope", async () => {
  const response = makeErrorResponse(
    new ChatAPIError("unsupported_model", "Unsupported model."),
    "request-123",
  );

  assertEquals(response.status, 422);
  assertEquals(await response.json(), {
    error: {
      code: "unsupported_model",
      message: "Unsupported model.",
      request_id: "request-123",
    },
  });
});

Deno.test("preserves additional response headers", () => {
  const response = makeErrorResponse(
    new ChatAPIError("method_not_allowed", "Only POST is supported."),
    "request-123",
    { Allow: "POST" },
  );

  assertEquals(response.status, 405);
  assertEquals(response.headers.get("Allow"), "POST");
});
