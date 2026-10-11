import {
  isSupportedModel,
  isSupportedProvider,
  resolveOpenRouterModel,
} from "./models.ts";
import { assert, assertEquals } from "./test_helpers.ts";

Deno.test("recognizes OpenAI models", () => {
  assert(isSupportedProvider("openai"));
  for (
    const model of [
      "gpt-6-luna",
      "gpt-6.1-sol",
      "gpt-5.6-luna",
      "gpt-5.6-terra",
      "gpt-5.6-sol",
      "gpt-6-astra",
    ]
  ) {
    assert(isSupportedModel("openai", model));
  }
});

Deno.test("recognizes Anthropic models", () => {
  assert(isSupportedProvider("anthropic"));
  for (
    const model of [
      "claude-opus-5-5",
      "claude-sonnet-5-5",
      "claude-haiku-5-5",
      "claude-opus-5",
      "claude-sonnet-5",
      "claude-haiku-4-5",
    ]
  ) {
    assert(isSupportedModel("anthropic", model));
  }
});

Deno.test("recognizes Google Gemini models", () => {
  assert(isSupportedProvider("google"));
  for (
    const model of [
      "gemini-3.8-flash",
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

for (
  const [provider, model, expected] of [
    ["openai", "gpt-6-luna", "openai/gpt-6-luna"],
    ["openai", "gpt-6.1-sol", "openai/gpt-6.1-sol"],
    ["openai", "gpt-6-astra", "openai/gpt-6-astra"],
    ["anthropic", "claude-opus-5-5", "anthropic/claude-opus-5.5"],
    ["anthropic", "claude-sonnet-5-5", "anthropic/claude-sonnet-5.5"],
    ["anthropic", "claude-haiku-5-5", "anthropic/claude-haiku-5.5"],
    ["google", "gemini-3.8-flash", "google/gemini-3.8-flash"],
    ["google", "gemini-3.5-flash-lite", "google/gemini-3.5-flash-lite"],
    ["openai", "gpt-5.6-luna", "openai/gpt-5.6-luna"],
    ["openai", "gpt-5.6-terra", "openai/gpt-5.6-terra"],
    ["openai", "gpt-5.6-sol", "openai/gpt-5.6-sol"],
    ["anthropic", "claude-opus-5", "anthropic/claude-opus-5"],
    ["anthropic", "claude-sonnet-5", "anthropic/claude-sonnet-5"],
    ["anthropic", "claude-haiku-4-5", "anthropic/claude-haiku-4.5"],
    ["google", "gemini-3.6-flash", "google/gemini-3.6-flash"],
    ["google", "gemini-3.5-flash", "google/gemini-3.5-flash"],
  ]
) {
  Deno.test(`resolves ${provider}/${model} without substituting another model`, () => {
    assertEquals(resolveOpenRouterModel(provider, model), expected);
  });
}
