import type { Plugin } from '@opencode-ai/plugin'

async function bell(): Promise<void> {
  await Bun.write(Bun.stdout, '\x07')
}

export const NotificationPlugin: Plugin = async ({ $, client }) => {
  return {
    event: async ({ event }) => {
      switch (event.type) {
        case 'session.idle':
          session = await ctx.client.session.get({ path: { id: event.properties.sessionID } })

          if (session.data?.parentID) {
            // Subagent
            return
          }

          await bell()
          break
        case 'question.asked':
          await bell()
          break
        case 'permission.asked':
          await bell()
          break
      }
    },
  }
}
