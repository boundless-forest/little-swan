# Privacy

Little Swan is a local macOS application and does not include analytics, advertising, telemetry, crash reporting, or its own backend service.

## Data stored on the Mac

- Provider API keys, provider selection, endpoint and model settings, shortcuts, common phrases, and interface preferences are stored in plaintext JSON at `~/Library/Application Support/Little Swan/config.json`.
- The five working drafts are stored in `~/Library/Application Support/Little Swan/source-drafts.json` so they remain available after relaunching the app.
- Little Swan does not create a separate translation-history database.
- Screenshots and recognized screen context are not written to disk or added to draft history.

The configuration and draft files are written with permissions that restrict access to the current macOS user. The API keys are not encrypted, and other software running as that user may still be able to read them.

## Data sent over the network

When translation, input polishing, or connection testing is used, Little Swan sends the relevant request directly to the provider endpoint selected in Settings. This may be DeepSeek, OpenAI, OpenRouter, or a custom compatible endpoint. Source text, prompts added by Little Swan, the selected model identifier, and authentication information needed by that provider are included in the request.

When screen context is enabled and available, contextual Polish also sends the source application name, available window title, and the visible text recognized from the captured window. The screenshot itself is processed locally with macOS text recognition and is never sent to the provider. The recognized context remains in memory only for the active request and its accept-or-reject review. If context is disabled, permission is unavailable, or capture fails, Polish continues using the Source alone.

Remote endpoints must use HTTPS. Unencrypted HTTP is accepted only for loopback addresses such as `localhost` for local development services.

Each provider controls its own processing, logging, retention, and training policies. Review the selected provider's terms and privacy policy before sending sensitive text.

## Screen Recording access

Optional screen context requires macOS Screen Recording permission. Immediately before showing its panel, Little Swan locks the exact frontmost external window across all connected displays. When the user later invokes Polish, it captures one snapshot of that locked window only. It does not capture continuously, record video, or monitor the screen in the background.

The captured image is held in memory long enough to recognize visible text, then discarded. The interface shows which application and window supplied the context and lets the user inspect the recognized text while reviewing the proposed edit.

## Clipboard access

Little Swan writes generated output to the clipboard only when the user clicks Copy or enables automatic copying for manual generation. It does not monitor clipboard contents.

## Removing local data

Delete `~/Library/Application Support/Little Swan` to remove API keys, preferences, and drafts.
