import { ChatAPIError } from "./errors.ts";

/** Stable ChatLLM model IDs mapped to OpenRouter's catalog IDs. */
export const openRouterModels = {
  openai: {
    "gpt-6-luna": "openai/gpt-6-luna",
    "gpt-6.1-sol": "openai/gpt-6.1-sol",
    "gpt-6-astra": "openai/gpt-6-astra",
    // Retain original model identities for existing chats and older clients.
    "gpt-5.6-luna": "openai/gpt-5.6-luna",
    "gpt-5.6-terra": "openai/gpt-5.6-terra",
    "gpt-5.6-sol": "openai/gpt-5.6-sol",
  },
  anthropic: {
    "claude-opus-5-5": "anthropic/claude-opus-5.5",
    "claude-sonnet-5-5": "anthropic/claude-sonnet-5.5",
    "claude-haiku-5-5": "anthropic/claude-haiku-5.5",
    // Older conversations continue with the model originally selected.
    "claude-opus-5": "anthropic/claude-opus-5",
    "claude-sonnet-5": "anthropic/claude-sonnet-5",
    "claude-haiku-4-5": "anthropic/claude-haiku-4.5",
  },
  google: {
    "gemini-3.8-flash": "google/gemini-3.8-flash",
    // Older Flash versions remain available for existing conversations.
    "gemini-3.6-flash": "google/gemini-3.6-flash",
    "gemini-3.5-flash": "google/gemini-3.5-flash",
    "gemini-3.5-flash-lite": "google/gemini-3.5-flash-lite",
  },
} as const satisfies Readonly<Record<string, Readonly<Record<string, string>>>>;

export type SupportedProvider = keyof typeof openRouterModels;

/** Returns whether the model author is registered with the Chat API. */
export function isSupportedProvider(
  provider: string,
): provider is SupportedProvider {
  return Object.hasOwn(openRouterModels, provider);
}

/** Returns whether the model is accepted for a registered author. */
export function isSupportedModel(
  provider: SupportedProvider,
  model: string,
): boolean {
  return Object.hasOwn(openRouterModels[provider], model);
}

/** Resolves only allowlisted models, preserving existing app and stored IDs. */
export function resolveOpenRouterModel(
  provider: string,
  model: string,
): string {
  if (!isSupportedProvider(provider)) {
    throw new ChatAPIError(
      "unsupported_provider",
      `Provider '${provider}' is not supported.`,
    );
  }
  if (!isSupportedModel(provider, model)) {
    throw new ChatAPIError(
      "unsupported_model",
      `Model '${model}' is not supported by provider '${provider}'.`,
    );
  }
  const models: Readonly<Record<string, string>> = openRouterModels[provider];
  return models[model];
}
