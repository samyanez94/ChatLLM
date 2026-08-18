const openAIModels: ReadonlySet<string> = new Set([
  "gpt-5.6-luna",
  "gpt-5.6-terra",
  "gpt-5.6-sol",
]);

const anthropicModels: ReadonlySet<string> = new Set([
  "claude-opus-5",
  "claude-sonnet-5",
  "claude-haiku-4-5",
]);

const googleModels: ReadonlySet<string> = new Set([
  "gemini-3.6-flash",
  "gemini-3.5-flash",
  "gemini-3.5-flash-lite",
]);

/** Provider and model combinations accepted by the Chat API. */
export const supportedModels = {
  openai: openAIModels,
  anthropic: anthropicModels,
  google: googleModels,
} as const satisfies Readonly<Record<string, ReadonlySet<string>>>;

export type SupportedProvider = keyof typeof supportedModels;

/** Returns whether the provider is registered with the Chat API. */
export function isSupportedProvider(
  provider: string,
): provider is SupportedProvider {
  return Object.hasOwn(supportedModels, provider);
}

/** Returns whether the model is accepted for a registered provider. */
export function isSupportedModel(
  provider: SupportedProvider,
  model: string,
): boolean {
  return supportedModels[provider].has(model);
}
