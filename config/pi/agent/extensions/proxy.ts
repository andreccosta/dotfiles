import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const fireworksBaseUrl = process.env.FIREWORKS_API_URL;
  if (fireworksBaseUrl) {
    pi.registerProvider("fireworks", {
      baseUrl: fireworksBaseUrl.replace(/\/+$/, ""),
    });
  }

  const codexBaseUrl = process.env.CODEX_LB_API_URL;
  if (codexBaseUrl) {
    pi.registerProvider("work", {
      baseUrl: codexBaseUrl.replace(/\/+$/, ""),
    });
  }
}
