import { isSupportedModel, isSupportedProvider } from "./models.ts";
import { assert, assertEquals } from "./test_helpers.ts";

Deno.test("recognizes the supported provider and models", () => {
  assert(isSupportedProvider("openai"));
  for (
    const model of ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"]
  ) {
    assert(isSupportedModel("openai", model));
  }
});

Deno.test("rejects unknown providers and models", () => {
  assertEquals(isSupportedProvider("example-provider"), false);
  assertEquals(isSupportedModel("openai", "example-model"), false);
});
