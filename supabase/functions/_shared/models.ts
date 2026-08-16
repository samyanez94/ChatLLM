const openAIModels: ReadonlySet<string> = new Set([
  "gpt-5.6-luna",
  "gpt-5.6-terra",
  "gpt-5.6-sol",
]);

/** Provider and model combinations accepted by the Chat API. */
export const supportedModels = {
  openai: openAIModels,
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
