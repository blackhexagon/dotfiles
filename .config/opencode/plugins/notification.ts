import { spawn } from "node:child_process";

interface PermissionEvent {
  readonly effect: string;
  readonly action: string;
  readonly message?: string;
}

interface ToolEvent {
  readonly tool: string;
  readonly input: unknown;
}

interface SessionIdleEvent {
  readonly type: "session.idle";
  readonly data: { readonly sessionID: string };
}

interface PluginContext {
  readonly location: {
    readonly project: { readonly canonical: string; readonly id: string };
  };
  readonly event: {
    subscribe(options: {
      readonly signal: AbortSignal;
    }): AsyncIterable<{ readonly type: string; readonly data: unknown }>;
  };
  readonly session: {
    get(input: {
      readonly sessionID: string;
    }): Promise<{ readonly parentID?: string } | undefined>;
  };
  readonly permission: {
    hook(
      name: "evaluate",
      callback: (event: PermissionEvent) => void | Promise<void>,
    ): Promise<unknown>;
  };
  readonly tool: {
    hook(
      name: "execute.before",
      callback: (event: ToolEvent) => void | Promise<void>,
    ): Promise<unknown>;
  };
}

const run = (command: string, args: readonly string[]) =>
  new Promise<void>((resolve) => {
    const child = spawn(command, args, { stdio: "ignore" });
    child.on("error", () => resolve());
    child.on("close", () => resolve());
  });

export default {
  id: "omarchy-notifications",
  async setup(ctx: PluginContext) {
    const projectName =
      ctx.location.project.canonical.split("/").filter(Boolean).at(-1) ??
      ctx.location.project.id;

    const notify = (glyph: string, status: string, detail?: string) =>
      run("omarchy", [
        "notification",
        "send",
        "-g",
        glyph,
        "--app-name",
        "OpenCode",
        projectName,
        detail ? `${status}: ${detail}` : status,
      ]);

    const controller = new AbortController();

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({
          signal: controller.signal,
        })) {
          if (event.type !== "session.idle") continue;
          const { sessionID } = event.data as SessionIdleEvent["data"];
          const session = await ctx.session.get({ sessionID });
          if (!session || session.parentID) continue;

          process.stdout.write("\x07");
          await notify("󰄬", "Finished");
        }
      } catch {
        // The event stream is aborted when the plugin unloads.
      }
    })();

    await ctx.permission.hook("evaluate", (event) => {
      if (event.effect !== "ask") return;
      return notify("󰋗", "Action needed", event.message ?? event.action);
    });

    await ctx.tool.hook("execute.before", (event) => {
      if (event.tool !== "question") return;
      const question = (
        event.input as {
          questions?: Array<{ header?: string; question?: string }>;
        }
      ).questions?.[0];
      return notify(
        "󰋗",
        "Action needed",
        question?.header ?? question?.question,
      );
    });

    return () => controller.abort();
  },
};
