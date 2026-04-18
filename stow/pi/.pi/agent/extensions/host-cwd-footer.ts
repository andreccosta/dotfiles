/**
 * Host + CWD footer extension
 *
 * Replaces pi's default footer so the hostname is shown together with the
 * working directory, while preserving the default footer styling and stats.
 */

import { homedir, hostname } from "node:os";

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

const HOST = hostname();
const HOME = homedir();

const formatTokens = (count: number): string => {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
	return `${Math.round(count / 1000000)}M`;
};

const sanitizeStatusText = (text: string): string => {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
};

const formatPath = (cwd: string): string => {
	if (cwd === HOME) {
		return "~";
	}
	if (cwd.startsWith(`${HOME}/`)) {
		return `~${cwd.slice(HOME.length)}`;
	}
	return cwd;
};

const isSshSession = (): boolean => {
	return Boolean(process.env.SSH_CONNECTION || process.env.SSH_CLIENT || process.env.SSH_TTY);
};

const setCustomFooter = (pi: ExtensionAPI, ctx: ExtensionContext) => {
	ctx.ui.setFooter((tui, theme, footerData) => {
		const dispose = footerData.onBranchChange(() => tui.requestRender());

		return {
			dispose,
			invalidate() { },
			render(width: number): string[] {
				let totalInput = 0;
				let totalOutput = 0;
				let totalCacheRead = 0;
				let totalCacheWrite = 0;
				let totalCost = 0;

				for (const entry of ctx.sessionManager.getEntries()) {
					if (entry.type === "message" && entry.message.role === "assistant") {
						const message = entry.message as AssistantMessage;
						totalInput += message.usage.input;
						totalOutput += message.usage.output;
						totalCacheRead += message.usage.cacheRead;
						totalCacheWrite += message.usage.cacheWrite;
						totalCost += message.usage.cost.total;
					}
				}

				const contextUsage = ctx.getContextUsage();
				const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
				const contextPercentValue = contextUsage?.percent ?? 0;
				const contextPercent = contextUsage?.percent !== null ? contextPercentValue.toFixed(1) : "?";

				let location = isSshSession() ? `${HOST}:${formatPath(ctx.cwd)}` : formatPath(ctx.cwd);
				const branch = footerData.getGitBranch();
				if (branch) {
					location += ` (${branch})`;
				}

				const sessionName = ctx.sessionManager.getSessionName();
				if (sessionName) {
					location += ` • ${sessionName}`;
				}

				const statsParts: string[] = [];
				if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
				if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
				if (totalCacheRead) statsParts.push(`R${formatTokens(totalCacheRead)}`);
				if (totalCacheWrite) statsParts.push(`W${formatTokens(totalCacheWrite)}`);

				const usingSubscription = ctx.model ? ctx.modelRegistry.isUsingOAuth(ctx.model) : false;
				if (totalCost || usingSubscription) {
					statsParts.push(`$${totalCost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`);
				}

				const contextPercentDisplay =
					contextPercent === "?" ? `?/${formatTokens(contextWindow)}` : `${contextPercent}%/${formatTokens(contextWindow)}`;

				let contextPercentStr: string;
				if (contextPercentValue > 90) {
					contextPercentStr = theme.fg("error", contextPercentDisplay);
				} else if (contextPercentValue > 70) {
					contextPercentStr = theme.fg("warning", contextPercentDisplay);
				} else {
					contextPercentStr = contextPercentDisplay;
				}
				statsParts.push(contextPercentStr);

				let statsLeft = statsParts.join(" ");
				let statsLeftWidth = visibleWidth(statsLeft);
				if (statsLeftWidth > width) {
					statsLeft = truncateToWidth(statsLeft, width, "...");
					statsLeftWidth = visibleWidth(statsLeft);
				}

				const modelName = ctx.model?.id || "no-model";
				let rightSide = modelName;
				if (ctx.model?.reasoning) {
					const thinkingLevel = pi.getThinkingLevel();
					rightSide = thinkingLevel === "off" ? `${modelName} • thinking off` : `${modelName} • ${thinkingLevel}`;
				}

				if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
					const withProvider = `(${ctx.model.provider}) ${rightSide}`;
					if (statsLeftWidth + 2 + visibleWidth(withProvider) <= width) {
						rightSide = withProvider;
					}
				}

				const rightSideWidth = visibleWidth(rightSide);
				let statsLine: string;
				if (statsLeftWidth + 2 + rightSideWidth <= width) {
					statsLine = statsLeft + " ".repeat(width - statsLeftWidth - rightSideWidth) + rightSide;
				} else {
					const availableForRight = width - statsLeftWidth - 2;
					if (availableForRight > 0) {
						const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
						statsLine =
							statsLeft + " ".repeat(Math.max(0, width - statsLeftWidth - visibleWidth(truncatedRight))) + truncatedRight;
					} else {
						statsLine = statsLeft;
					}
				}

				const locationLine = truncateToWidth(theme.fg("dim", location), width, theme.fg("dim", "..."));
				const dimStatsLeft = theme.fg("dim", statsLeft);
				const dimRemainder = theme.fg("dim", statsLine.slice(statsLeft.length));
				const lines = [locationLine, dimStatsLeft + dimRemainder];

				const extensionStatuses = footerData.getExtensionStatuses();
				if (extensionStatuses.size > 0) {
					const statusLine = Array.from(extensionStatuses.entries())
						.sort(([a], [b]) => a.localeCompare(b))
						.map(([, text]) => sanitizeStatusText(text))
						.join(" ");
					lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
				}

				return lines;
			},
		};
	});
};

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (event, ctx) => {
		if (event.reason === "startup" || event.reason === "new" ||
			event.reason === "resume" || event.reason === "fork") {
			setCustomFooter(pi, ctx);
		}
	});
}
