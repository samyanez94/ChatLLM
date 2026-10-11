# ChatLLM

ChatLLM is a personal iOS project built to gain more hands-on experience with
Apple's Foundation Models framework and LLMs from other providers. It's a
practical place to experiment, compare models, and try out new ideas—not a
production app.

The idea is pretty simple: one chat interface that can talk to both on-device
and hosted models, with all the provider-specific plumbing tucked out of sight.

## Screenshots

<p align="center">
  <img src="docs/images/chat-list.png" width="30%" alt="ChatLLM chat list">
  <img src="docs/images/model-selection.png" width="30%" alt="ChatLLM model selection">
  <img src="docs/images/chat.png" width="30%" alt="A conversation in ChatLLM">
</p>

## Features

- Chat with Apple's on-device Foundation Model on supported devices.
- Chat with supported OpenAI, Anthropic, and Google Gemini models through OpenRouter behind a Supabase Edge Function.
- Choose models grouped by provider, with short descriptions and availability
  information.
- Persist chat history locally and restore conversations across app launches.
- Continue hosted conversations using their locally saved transcripts.
- Surface safe backend errors and request identifiers for troubleshooting.
- Cover the client and backend contract with Swift Testing and Deno tests.

## Project Goals

- Get comfortable with Foundation Models and how availability varies across
  devices.
- Compare on-device inference with hosted LLMs.
- Explore a provider-neutral model and service architecture.
- Practice modern SwiftUI, Observation, Swift concurrency, and Swift Testing.
- Learn how to keep provider credentials out of an iOS app.

## Architecture

There are two main pieces:

- `ChatLLM/` — the SwiftUI app. Each conversation gets its own provider service
  and sticks with one model.
- `supabase/functions/` — a lightweight backend that validates the public chat
  contract, keeps the OpenRouter API key on the server, and calls the selected
  hosted model through one OpenRouter adapter.

For hosted models, the app sends the model author, model, and local transcript to
the backend. The backend maps the stable ChatLLM model identifiers to an explicit
OpenRouter allowlist. OpenRouter automatically chooses an available hosting
endpoint for that model, with its default endpoint fallback behavior. The app's
`provider` field still identifies the model author (OpenAI, Anthropic, or Google),
not the hosting endpoint. Requests do not add privacy restrictions beyond the
OpenRouter account's settings.

The app stores chats and messages locally with SwiftData. Hosted requests send
the full transcript on every turn. Legacy continuation IDs are accepted and
ignored by the backend, and cleared by the app after the next successful reply.
Existing chat and model IDs are preserved, so no database migration is needed.
On-device Foundation Models sessions are reconstructed from their saved
transcripts when the app launches again.

The full API contract lives in [docs/chat-api.md](docs/chat-api.md).

## Supported Models

New conversations offer Apple's on-device model and eight remote choices:

- Apple Foundation Model — private, on-device generation through Apple's
  Foundation Models framework.
- GPT-6 Luna — the fast and economical OpenAI option.
- GPT-6.1 Sol — the balanced OpenAI option for coding and everyday work.
- GPT-6 Astra — the most capable OpenAI option, using low reasoning by default.
- Claude Opus 5.5 — Anthropic's powerful option for complex coding and knowledge work.
- Claude Sonnet 5.5 — Anthropic's balanced option for everyday conversations.
- Claude Haiku 5.5 — Anthropic's fast and economical option for frequent tasks.
- Gemini 3.8 Flash — Google's capable general-purpose option.
- Gemini 3.5 Flash-Lite — Google's fast and economical option.

Saved conversations retain their original model. GPT-5.6 Luna/Terra/Sol,
Claude Opus 5/Sonnet 5/Haiku 4.5, and Gemini 3.6 Flash/3.5 Flash remain supported
for those chats, but are hidden from the new-chat picker. Their identifiers are
not remapped to newer versions, and no database migration is required.

The hosted models need the ChatLLM backend to be configured. The Apple model
depends on the device supporting Apple Intelligence, having it enabled, and
the model being ready.

## Requirements

- Xcode with the iOS 26.5 SDK or newer.
- An iOS 26.5 simulator or device.
- An Apple Intelligence-capable device to use the on-device model.
- A Supabase project and an OpenRouter API key with available credits to use hosted models.
- Supabase CLI and Deno when developing or testing the backend locally.

## Getting Started

1. Open `ChatLLM.xcodeproj` in Xcode.
2. Copy the example backend configuration:

   ```sh
   cp Configuration/ChatLLMConfiguration.plist.example \
     ChatLLM/Configuration/ChatLLMConfiguration.plist
   ```

3. Replace the placeholder endpoint and publishable key in the copied file
   with values from your Supabase project.
4. Select an iOS 26.5 device or simulator and run the `ChatLLM` scheme.

The local configuration file is ignored by Git. The Supabase publishable key
is okay to include in a client app, but Supabase secret credentials and the
OpenRouter API key should never be added to the iOS project.

You can still run the app without any backend configuration. The hosted models
will show up as unavailable, but the Apple Foundation Model will work if the
device supports it.

## Backend Setup

To use the hosted models, link the repo to a Supabase project, add the OpenRouter
secret, and deploy the chat function:

```sh
supabase link --project-ref <project-ref>
supabase secrets set OPENROUTER_API_KEY=<openrouter-api-key>
supabase functions deploy chat
```

The secret can also be set in the Supabase dashboard. The iOS app continues to
use the Supabase publishable key; do not put the OpenRouter key in its plist.
The previous `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GEMINI_API_KEY` secrets
are no longer used by this version.

After deployment, use the function URL and the project's publishable key in
`ChatLLMConfiguration.plist`.

The endpoint currently uses a publishable project key instead of end-user
authentication. That's plenty for this personal project, but it isn't meant to
provide production-grade abuse prevention or per-user authorization.

## Testing

Run the iOS tests from Xcode with **Product > Test**, or use an installed
simulator from the command line:

```sh
xcodebuild test \
  -project ChatLLM.xcodeproj \
  -scheme ChatLLM \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5'
```

Run the backend unit tests with Deno:

```sh
deno test supabase/functions/_shared
deno lint supabase/functions/_shared supabase/functions/chat/index.ts
```

The backend tests use fake OpenRouter responses and require no API keys or
network permissions. They cover the public handler, model allowlist, full
transcripts with legacy continuations, response parsing, and safe error mapping.

## Deploying the OpenRouter Migration

1. Confirm `OPENROUTER_API_KEY` is set in the linked Supabase project and the
   OpenRouter account has available credits.
2. Run the backend and iOS tests above, then deploy with
   `supabase functions deploy chat`.
3. Send a short message using one OpenAI, one Anthropic, and one Gemini model.
   Confirm each receives a reply and subsequent turns retain context.
4. Reopen an existing OpenAI or Gemini conversation and continue it. The saved
   transcript should work even if it still contains a legacy continuation ID.
5. After verification, remove the unused direct-provider secrets if desired.
   Retain them until then if you want to be able to redeploy the previous backend.

All sixteen current and legacy remote models were present in the
[OpenRouter catalog](https://openrouter.ai/api/v1/models) when checked on
October 11, 2026. Catalog availability does not verify account-specific access;
the post-deployment checks above exercise that access.

## Rolling Out a Model Catalog Update

Deploy the backend allowlist before running or distributing the updated iOS app:

```sh
supabase functions deploy chat
```

The allowlist accepts both the eight current models and the eight older models
retained for saved chats. Older app builds can continue using their existing
lineup. In the updated app, verify that new chats show the refreshed choices and
that older conversations reopen with their original model name and history.

## Current Limitations

Response streaming isn't supported yet, and the backend isn't set up for
production authentication. Persistence is also still early in development, so
schema changes may require deleting the app or simulator data. These are areas
that may be explored further, along with support for more providers.
