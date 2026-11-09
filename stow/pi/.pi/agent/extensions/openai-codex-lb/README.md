# Work Codex LB

Registers `work` with the Codex adapter, upstream model metadata, and priority fast
aliases. Requires a filesystem copy of `@earendil-works/pi-ai` compatible with Pi.

## Configuration

- `CODEX_LB_API_KEY`: required `sk-clb-...` key; no stored-credential fallback.
- `CODEX_LB_URL`: defaults to `http://localhost:2455/v1`;
  `CODEX_LB_BASE_URL` is a fallback variable.
- `CODEX_LB_TRANSPORT`: `codex` (default) or `responses`.

Codex maps `/v1` to `/backend-api/codex/responses`; Pi's `transport` setting selects
SSE or WebSockets. Use `CODEX_LB_TRANSPORT=responses pi` for `/v1/responses`.

Model overrides: `providers.work.modelOverrides` in `models.json`.

## Tests

From `stow/pi/.pi/agent`: `pnpm test:codex-lb` or
`pnpm test:codex-lb:live` (requires Pi, credentials, and server access; billable).
