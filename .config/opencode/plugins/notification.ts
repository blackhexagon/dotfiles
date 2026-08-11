import type { Plugin } from "@opencode-ai/plugin";

export const NotificationPlugin = (async ({ $, project }) => {
  const projectName =
    project.worktree.split("/").filter(Boolean).at(-1) ?? project.id;
  const notify = async (glyph: string, status: string, detail?: string) => {
    const description = detail ? `${status}: ${detail}` : status;
    await $`omarchy notification send ${glyph} ${projectName} ${description} -a OpenCode`;
  };

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`printf '\a'`;
        await notify("󰄬", "Finished");
      }
    },
    "permission.ask": async (input, output) => {
      if (output.status === "ask") {
        await notify("󰋗", "Action needed", input.title);
      }
    },
    "tool.execute.before": async ({ tool }, output) => {
      if (tool === "question") {
        const question = output.args.questions?.[0];
        await notify(
          "󰋗",
          "Action needed",
          question?.header ?? question?.question,
        );
      }
    },
  };
}) satisfies Plugin;
