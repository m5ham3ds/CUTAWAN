# Phase 7 — Multi-provider AI, local/remote selection and secure credentials

## Goal

Allow the user to keep local inference or explicitly choose an external provider/model, save their own API key securely, refresh the models visible to that key and test a selected text model before using it in CUTAWAN.

## Provider architecture

- `AiProviderCatalog`: metadata for OpenAI, Gemini, Hugging Face Inference Providers and generic OpenAI-compatible endpoints.
- `AiCredentialStore`: provider-scoped key, endpoint, selected model, active provider, execution mode and cloud consent.
- `AiSecretStorage`: injectable storage contract for tests.
- `FlutterAiSecretStorage`: Android secure-storage adapter supplied by `flutter_secure_storage`.
- `AiModelGateway`: provider-specific model list, connection test and bounded text-completion calls.
- `LocalEditorialAnnotationService`: same candidate annotation allow-list for local Qwen and remote providers.
- `ModelsPage`: local model installation plus provider selection, key entry/rotation/removal, model discovery, default model, test request and local/remote consent.

## Provider details

### OpenAI

- Base URL is fixed to `https://api.openai.com/v1/`.
- Models: `GET /models` with Bearer key.
- Completion: `POST /chat/completions`.
- Key is never passed in query parameters.

### Gemini

- Base URL is fixed to `https://generativelanguage.googleapis.com/v1beta/`.
- List: `GET /models` with `x-goog-api-key`.
- Completion: try Interactions `POST /interactions`; if the endpoint/model is explicitly unsupported, fall back to `POST /models/{model}:generateContent`.
- Both endpoints use the key header and never place the key in the URI.

### Hugging Face

- Base URL is fixed to `https://router.huggingface.co/v1/`.
- Models: account/router list via `GET /models`.
- Completion: `POST /chat/completions`.
- `providers[].is_free` is treated as upstream metadata, not a blanket guarantee of free service; quota and provider selection may change.

### Compatible endpoint

- User supplies an HTTPS base URL and optional Bearer API key.
- Only the OpenAI-compatible `/models` and `/chat/completions` contract is supported.
- HTTP is accepted only for emulator/local loopback addresses; arbitrary public HTTP endpoints are rejected.
- Proprietary APIs need dedicated adapters in later work.

## Secret and privacy rules

- Save key only in secure storage; never in project preferences/JSON.
- Mask the input field and clear it immediately after save.
- UI shows only that a key is stored, never the stored value.
- Allow replacement and explicit delete.
- Android `allowBackup=false` avoids restoring encrypted settings to a different device without the originating Keystore key.
- Cloud mode remains opt-in; a disabled consent blocks requests.
- Phase 7 only sends short transcript excerpts/candidate IDs for editorial text. Video bytes are never sent by this feature.
- The LLM may change title/hook/summary/explanations for existing candidates only. IDs, times, scores and evidence remain deterministic.
- Errors include HTTP status/provider code only, not raw body contents or secrets.

## Acceptance tests

1. Secure-store adapter saves, reads and deletes provider keys.
2. Reject malformed/oversized key input and arbitrary public HTTP base URLs.
3. OpenAI model discovery and chat completion request paths/headers.
4. Gemini model discovery and Interactions fallback to GenerateContent.
5. Hugging Face model list, context metadata and upstream free indicator.
6. Wrong Gemini host rejected.
7. Remote mode cannot be selected without cloud consent and a stored model.
8. Model annotations preserve IDs, timestamps, scores and evidence.
9. Format/analyze/tests/build and ARM64 native-library assertion on Actions.
10. Physical Android test of Keystore, backup, rotation and deletion remains mandatory.

## Constraints / not claimed

- A model list is not proof that the model supports chat completion or that the account can afford it.
- No static list is claimed to contain all models. The user-visible list is requested from the signed-in account/provider.
- Free status is displayed only where the provider reports it.
- This provider adapter does not cover arbitrary custom API schemas (Anthropic Messages, Cohere, local Ollama native API, etc.) unless they implement the supported OpenAI-compatible API.
- This phase does not cloud-transcribe video/audio or upload video files.
- Secure-storage unit tests with an injected fake do not prove Android Keystore integration on a physical device.

## Next steps

- Add provider-specific error classifications and rate-limit/retry behavior without logging prompt/key contents.
- Add a cancellable model request, timeout and per-provider capability filters.
- Add separate endpoint adapters for any desired proprietary API that is not OpenAI-compatible.
- Add secure-storage instrumented tests on Android device/emulator.
- Integrate selected providers into transcript summarization/clip review only with per-task consent and explicit data preview.


## Verified implementation and build result

- Implementation was committed directly to `main` in `dc81449eda1aedaf8202d0860e593696016ea658`; follow-up fixes repaired Android script generation, Dart types/imports and emulator-local endpoint validation. The final tested source is `4a9c8b3a22c62390ab43d1c5e84e90a7fa16fc95`.
- Mobile Android Actions run: [44767326112](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44767326112) — success.
- Root CI run: [44767326104](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44767326104) — success.
- All **79 Flutter unit/widget tests** passed. Format and static analysis passed with `--fatal-infos`.
- Android platform generation, package resolution and `bash -n` preflight passed.
- ARM64 debug APK built, then the workflow verified `arm64-v8a` as the only packaged ABI, all 10 native library basenames unique, and the Whisper + llama required shared libraries present.
- Extracted APK: 95,279,731 bytes. SHA-256: `47b205348a5731aced8bfd50c56ebb46cbd08e2c6b8b2f8e6e14f9a5e86d31da`.
- Model Center uses `flutter_secure_storage` for credentials and provider preferences. Android backup is disabled by the generation script. Unit tests use a mock secret-store interface; a physical Android Keystore verification is still required.
