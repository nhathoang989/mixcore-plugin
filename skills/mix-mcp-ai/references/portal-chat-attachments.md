# Portal chat attachments — images and voice

The portal's built-in AI chat (the **Ask AI** panel) accepts screenshots/photos and recorded voice messages inside a normal chat turn — tools, plans and memory keep working. This is the portal panel, not a CMS site chat widget (those are text-only; see [chat-widget.md](chat-widget.md)).

## What users can send

| | Images | Voice |
|---|---|---|
| How | paste (Cmd/Ctrl+V), drag-and-drop on the panel, or the 📎 button | mic button → record, click again to stop; Esc cancels |
| Types | png, jpeg, webp, gif | webm, ogg, mp3, wav, m4a |
| Max size | 5 MB | 10 MB; recording auto-stops at 2:00 |
| Per message | up to **4 attachments**; a message may be attachments-only | |

Files upload to a **private** store readable only by the uploading user in their tenant (`POST/GET /api/v1/ai/chat/attachments`, portal session cookie). Another user's attachment id is treated as not found.

## Images → vision model

- The image is sent to the model **for the current turn only**. History keeps the text plus an `[image: {fileName}]` placeholder — later turns cannot see the image again; ask the user to re-attach it if needed.
- If the selected chat model can't read images, that turn is routed to the configured vision model (credential **Default VLM model**, else **Default Omni model**) and the chat shows `Using {model} to read your image.`
- With no vision model configured the turn is rejected: `This chat model can't read images and no vision model is configured. Set a Default VLM model in AI Settings.`
- An image sent with no text is asked as `Please look at the attached image.`

## Voice → transcript

- With a **Default STT model** configured, the recording is transcribed on the server and becomes the turn text: `[Voice message]: {transcript}` (or `{message}\n\n[Voice message]: {transcript}` when text was typed too). The transcript also appears under the voice chip.
- Setup (AI Settings → credential with an API key):

| Provider | Default STT model | Base URL |
|---|---|---|
| OpenAI | `gpt-4o-transcribe` or `whisper-1` | optional (defaults to OpenAI) |
| Groq | `whisper-large-v3` | **required**: `https://api.groq.com/openai/v1` |
| OpenRouter | `openai/whisper-1` (no `~` prefix) | **required**: `https://openrouter.ai/api/v1` |

  A non-OpenAI credential without a Base URL is never used for speech-to-text (its key is not sent to OpenAI).
- The language is auto-detected by the model (Whisper-family models handle Vietnamese and most languages); no language setting is needed.
- No STT model → the mic falls back to **browser dictation**: speech becomes text in the input box, in the **browser's language** (`navigator.language`). Speaking Vietnamese with an English browser gives garbled text — set the browser/OS language, or configure an STT model.
- Silence/blank recordings are rejected: `I couldn't hear anything in that recording.` Missing STT for a recorded clip: `Voice messages need a speech-to-text model. Set a Default STT model in AI Settings.`
- Provider rejections show the provider's reason: `Speech-to-text failed: {message}` (e.g. `Model ~openai/whisper-1 does not exist` → fix the model name in AI Settings).

## Answering user questions

| Question | Answer |
|---|---|
| "Can you see my screenshot?" | Yes in the turn it was attached; afterwards only its file name remains. |
| "Why does the mic only type text?" | No Default STT model is configured — it's browser dictation. |
| "Can I speak Vietnamese?" | Yes with an STT model (auto-detect); with dictation only if the browser language is Vietnamese. |
| "Image rejected / too big?" | Check type and size limits above; max 4 per message. |
