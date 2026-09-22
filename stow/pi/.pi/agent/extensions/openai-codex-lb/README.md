# Work Codex LB extension

Registers the `work` provider against codex-lb's API-key-compatible OpenAI
Responses endpoint.

Configuration:

- `CODEX_LB_API_KEY` — Codex LB key (`sk-clb-...`). If unset, the extension checks `work` and then `openai` API-key credentials in `auth.json`.
- `CODEX_LB_URL` — codex-lb URL ending in `/v1`.
- `CODEX_LB_BASE_URL` — supported as a fallback for compatibility.

The provider intentionally uses `openai-responses` at `/v1/responses`. Do not
rewrite this URL to `/backend-api/codex/responses`: codex-lb's API-key path for
that Codex endpoint currently drops system instructions and tool definitions,
causing models to claim that Pi has no tools. The standard Responses endpoint
preserves both and supports Pi tool calls.
