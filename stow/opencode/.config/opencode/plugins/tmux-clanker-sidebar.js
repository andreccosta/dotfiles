import { spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const resolveHookScript = () => {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 4; i += 1) {
    const candidate = resolve(dir, "hook.sh");
    if (existsSync(candidate)) {
      return candidate;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  return null;
};

const run = (cmd, args) => {
  try {
    const child = spawnSync(cmd, args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
    if (child.status !== 0) return "";
    return typeof child.stdout === "string" ? child.stdout.trim() : "";
  } catch {
    return "";
  }
};

const resolveBinary = () => {
  const fromEnv = process.env.OPENCODE_TMUX_CLANKER_SIDEBAR_BIN;
  if (fromEnv) return fromEnv;

  const fromTmux = run("tmux", ["show-options", "-g", "-v", "@clanker_sidebar_bin"]);
  if (fromTmux) return fromTmux;

  const home = process.env.HOME ?? "";
  const candidates = [
    resolve(home, ".config/tmux/plugins/tmux-clanker-sidebar/bin/tmux-clanker-sidebar"),
    resolve(home, ".tmux/plugins/tmux-clanker-sidebar/bin/tmux-clanker-sidebar"),
    "tmux-clanker-sidebar",
  ];

  for (const candidate of candidates) {
    if (candidate === "tmux-clanker-sidebar" || existsSync(candidate)) {
      return candidate;
    }
  }

  return "tmux-clanker-sidebar";
};

const HOOK_COMMAND = (() => {
  const hookScript = resolveHookScript();
  if (hookScript) {
    return { cmd: "bash", prefix: [hookScript, "opencode"] };
  }

  const binary = resolveBinary();
  return { cmd: binary, prefix: ["hook", "opencode"] };
})();

const hook = (eventName, payload) => {
  try {
    const child = spawn(HOOK_COMMAND.cmd, [...HOOK_COMMAND.prefix, eventName], {
      stdio: ["pipe", "ignore", "ignore"],
    });
    child.on("error", () => {});
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify(payload));
  } catch {
    // Best-effort bridge only.
  }
};

const pickFirstString = (value, keys) => {
  for (const key of keys) {
    const candidate = value?.[key];
    if (typeof candidate === "string" && candidate) {
      return candidate;
    }
  }
  return "";
};

const errorMessage = (err) => {
  if (!err) return "";
  if (typeof err === "string") return err;
  if (typeof err === "object") {
    return pickFirstString(err, ["message", "name"]) || JSON.stringify(err);
  }
  return String(err);
};

const extractPromptText = (parts) => {
  if (!Array.isArray(parts)) return "";
  const chunks = [];
  for (const part of parts) {
    if (!part || part.type !== "text") continue;
    if (part.synthetic || part.ignored) continue;
    if (typeof part.text === "string" && part.text) {
      chunks.push(part.text);
    }
  }
  return chunks.join("\n");
};

export const TmuxClankerSidebar = async ({ directory }) => {
  const cwd = typeof directory === "string" ? directory : "";

  return {
    "chat.message": async (input, output) => {
      const session_id =
        typeof input?.sessionID === "string" ? input.sessionID : "";
      const prompt = extractPromptText(output?.parts);
      hook("user-prompt-submit", { cwd, session_id, prompt });
    },

    event: async ({ event }) => {
      if (!event || !event.type) return;
      const props = event.properties ?? {};
      const session_id = pickFirstString(props, ["sessionID", "sessionId", "session_id"]);

      switch (event.type) {
        case "session.created":
          hook("session-start", { cwd, session_id, source: "startup" });
          return;

        case "session.status": {
          const statusType = props.status?.type;
          if (statusType === "busy") {
            hook("user-prompt-submit", { cwd, session_id, prompt: "" });
          } else if (statusType === "idle") {
            hook("stop", { cwd, session_id, last_message: "" });
          }
          return;
        }

        case "session.idle":
          hook("stop", { cwd, session_id, last_message: "" });
          return;

        case "session.error":
          hook("stop-failure", {
            cwd,
            session_id,
            error: errorMessage(props.error) || "session.error",
          });
          return;

        case "permission.asked":
          hook("notification", { cwd, session_id, wait_reason: "permission" });
          return;
      }
    },

    "tool.execute.after": async (input, output) => {
      hook("activity-log", {
        cwd,
        session_id: input?.sessionID ?? "",
        tool_name: input?.tool ?? "",
        tool_input: input?.args ?? {},
        tool_response: {
          title: output?.title ?? "",
          output: output?.output ?? "",
          metadata: output?.metadata ?? null,
        },
      });
    },
  };
};
