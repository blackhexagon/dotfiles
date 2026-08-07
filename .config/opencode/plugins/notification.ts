import type { Plugin } from "@opencode-ai/plugin"

export const NotificationPlugin = (async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`printf '\a'`
      }
    },
  }
}) satisfies Plugin
