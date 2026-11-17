# Work Codex LB

Registers `work` with the Codex adapter and models discovered from the LB.
Requires a filesystem copy of `@earendil-works/pi-ai` compatible with Pi.

## Configuration

- `CODEX_LB_API_KEY`: required `sk-clb-...` key; no stored-credential fallback.
- `CODEX_LB_URL`: defaults to `http://localhost:2455/v1`;
  `CODEX_LB_BASE_URL` is a fallback variable.
- `CODEX_LB_TRANSPORT`: `codex` (default) or `responses`.

Codex maps `/v1` to `/backend-api/codex/responses`; Pi's `transport` setting selects
SSE or WebSockets. Use `CODEX_LB_TRANSPORT=responses pi` for `/v1/responses`.

## Model discovery

Authenticated `GET /v1/models` supplies the model list, names, context windows,
input capabilities, and reasoning levels. Discovery runs at startup (5-second
timeout) and through Pi's model-refresh lifecycle (5-minute freshness window;
forced refresh bypasses it). The discovery route stays `/v1/models` with either
transport. No inference request is needed.

Successful catalogs persist through Pi's provider-scoped model store. On failure,
the last successful catalog for the same endpoint and transport is retained;
without one, the bundled Codex catalog is the offline fallback. A successful LB
response replaces that fallback rather than adding models the LB did not list.
An empty successful list is authoritative too: it clears availability and is
persisted with endpoint/transport identity so offline startup restores no models.

Pi's bundled catalog fills missing pricing and output limits by exact model ID.
Unknown models use zero/unknown pricing and a conservative 16,384-token output
limit (capped at their context window); missing context windows default to 128,000.
Only text/image inputs and Pi-supported reasoning levels are exposed (`none`
maps to Pi's `off` setting). Discovery
never enables additional transport compatibility flags.

Model overrides: `providers.work.modelOverrides` in `models.json`, including
pricing/output limits for models not yet in Pi's bundled catalog.

## Tests

From `stow/pi/.pi/agent`: `pnpm test:codex-lb` or
`pnpm test:codex-lb:live` (requires Pi, credentials, and server access; billable).
