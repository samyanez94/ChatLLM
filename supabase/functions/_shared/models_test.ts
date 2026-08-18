import { isSupportedModel, isSupportedProvider } from "./models.ts";
import { assert, assertEquals } from "./test_helpers.ts";

Deno.test("recognizes OpenAI models", () => {
  assert(isSupportedProvider("openai"));
  for (
    const model of ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"]
  ) {
    assert(isSupportedModel("openai", model));
  }
});

Deno.test("recognizes Anthropic models", () => {
  assert(isSupportedProvider("anthropic"));
  for (
    const model of ["claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5"]
  ) {
    assert(isSupportedModel("anthropic", model));
  }
});

Deno.test("recognizes Google Gemini models", () => {
  assert(isSupportedProvider("google"));
  for (
    const model of [
      "gemini-3.6-flash",
      "gemini-3.5-flash",
      "gemini-3.5-flash-lite",
    ]
  ) {
    assert(isSupportedModel("google", model));
  }
  assertEquals(isSupportedModel("google", "example-model"), false);
});

Deno.test("rejects unknown providers and models", () => {
  assertEquals(isSupportedProvider("example-provider"), false);
  assertEquals(isSupportedModel("openai", "example-model"), false);
  assertEquals(isSupportedModel("anthropic", "example-model"), false);
});
