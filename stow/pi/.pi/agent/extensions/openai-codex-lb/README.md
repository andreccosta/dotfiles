# Work Codex LB extension

Imported from
[`gmcabrita/dotfiles`](https://github.com/gmcabrita/dotfiles/tree/d6b40e06f3ee0bc39c019bc019d0c8a1cff6044b/.pi/agent/extensions/openai-codex-lb)
and adapted to register the existing `work` provider.

The extension clones pi's built-in OpenAI Codex Responses adapter at runtime, patches it for Codex LB API-key authentication, and keeps its WebSocket transport and connection cache isolated from the built-in `openai-codex` provider. The `work` model catalogue remains declared in `../../models.json`; this extension supplies only the runtime provider behavior.

Configuration:

- `CODEX_LB_API_KEY` — Codex LB key (`sk-clb-...`). If unset, the extension checks `work` and then `openai` API-key credentials in `auth.json`.
- `CODEX_LB_URL` — existing work-provider URL. A trailing `/v1` is translated to the Codex `/backend-api` route.
- `CODEX_LB_BASE_URL` — supported as a fallback for compatibility with the upstream extension.
- `settings.json` must use `"transport": "websocket-cached"` to reuse the session WebSocket and send context deltas after the first request.

The source patches are intentionally fail-closed. After upgrading pi, run `openai-codex-lb.test.ts` or at least `pi --list-models work`; an upstream adapter change that invalidates a patch prevents the extension from silently using incorrect authentication or transport behavior.
