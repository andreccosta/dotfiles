import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CODEX_FAST_ALIASES: Readonly<Record<string, string>> = {
  "gpt-5.5-fast": "gpt-5.5",
  "gpt-5.6-sol-fast": "gpt-5.6-sol",
};

export function resolveCodexModelAlias(modelId: string): string {
  return CODEX_FAST_ALIASES[modelId] ?? modelId;
}

export default function (pi: ExtensionAPI) {
  pi.on("before_provider_request", (event, ctx) => {
    const model = ctx.model;
    const isCodexProvider =
      (model?.provider === "openai-codex" && model.api === "openai-codex-responses") ||
      (model?.provider === "work" && model.api === "work-codex-lb-responses");
    if (!isCodexProvider) return;

    const targetModel = resolveCodexModelAlias(model.id);
    if (targetModel === model.id) return;
    if (!event.payload || typeof event.payload !== "object" || Array.isArray(event.payload)) return;

    return {
      ...(event.payload as Record<string, unknown>),
      model: targetModel,
      service_tier: "priority",
    };
  });
}
