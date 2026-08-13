# OpenAI Codex compaction extension

Imported from
[`gmcabrita/dotfiles`](https://github.com/gmcabrita/dotfiles/tree/ad089f2502b8795769fd808f283976c3410a2c17/.pi/agent/extensions/openai-codex-compaction)
and adapted to support this repository's `work` / `work-codex-lb-responses`
provider identity in addition to the upstream OpenAI Codex identities.

The extension intercepts Pi compaction for supported Codex models and requests
provider-native remote compaction. It persists the opaque replacement history
in the Pi session while retaining a local text summary for portability and
fallback. If remote compaction fails, Pi uses the local summary.
