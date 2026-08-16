import {
  isSupportedModel,
  isSupportedProvider,
} from "./models.ts";
import { assert, assertEquals } from "./test_helpers.ts";

Deno.test("recognizes the supported provider and model", () => {
  assert(isSupportedProvider("openai"));
  assert(isSupportedModel("openai", "gpt-5.6-luna"));
});

Deno.test("rejects unknown providers and models", () => {
  assertEquals(isSupportedProvider("example-provider"), false);
  assertEquals(isSupportedModel("openai", "example-model"), false);
});
