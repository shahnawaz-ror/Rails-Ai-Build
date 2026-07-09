import { exec } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { promisify } from "node:util";
import { getConfig } from "./config.js";
import type { ToolDefinition } from "./providers.js";

const execAsync = promisify(exec);

const BLOCKED_SHELL = [/\brm\s+-rf\s+\//, /\bmkfs\b/, /\bdd\s+if=/];

export interface Tool {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
  execute(args: Record<string, unknown>): Promise<Record<string, unknown>>;
}

function resolvePath(workspace: string, filePath: string): string {
  const full = path.resolve(workspace, filePath.replace(/^\//, ""));
  if (!full.startsWith(path.resolve(workspace))) {
    throw new Error(`Path escapes workspace: ${filePath}`);
  }
  return full;
}

export function createTools(workspace: string): Record<string, Tool> {
  return {
    read_file: {
      name: "read_file",
      description: "Read the contents of a file in the workspace.",
      parameters: {
        type: "object",
        properties: {
          path: { type: "string" },
          offset: { type: "integer" },
          limit: { type: "integer" },
        },
        required: ["path"],
      },
      async execute(args) {
        const full = resolvePath(workspace, args.path as string);
        if (!fs.existsSync(full)) return { error: `File not found: ${args.path}` };
        const lines = fs.readFileSync(full, "utf-8").split("\n");
        const offset = Math.max(((args.offset as number) || 1) - 1, 0);
        const limit = args.limit as number | undefined;
        const selected = limit ? lines.slice(offset, offset + limit) : lines.slice(offset);
        const numbered = selected.map((line, i) => `${offset + i + 1}|${line}`);
        return { path: args.path, content: numbered.join("\n"), total_lines: lines.length };
      },
    },

    write_file: {
      name: "write_file",
      description: "Create or overwrite a file in the workspace.",
      parameters: {
        type: "object",
        properties: {
          path: { type: "string" },
          content: { type: "string" },
        },
        required: ["path", "content"],
      },
      async execute(args) {
        const full = resolvePath(workspace, args.path as string);
        fs.mkdirSync(path.dirname(full), { recursive: true });
        fs.writeFileSync(full, args.content as string);
        return { path: args.path, bytes_written: (args.content as string).length, status: "written" };
      },
    },

    grep: {
      name: "grep",
      description: "Search for a pattern in workspace files.",
      parameters: {
        type: "object",
        properties: {
          pattern: { type: "string" },
          path: { type: "string" },
          case_insensitive: { type: "boolean" },
        },
        required: ["pattern"],
      },
      async execute(args) {
        const flags = args.case_insensitive ? "i" : "";
        const regex = new RegExp(args.pattern as string, flags);
        const base = args.path ? resolvePath(workspace, args.path as string) : workspace;
        const matches: string[] = [];

        function walk(dir: string) {
          if (matches.length >= 100) return;
          for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            if (entry.name === ".git" || entry.name === "node_modules") continue;
            const full = path.join(dir, entry.name);
            if (entry.isDirectory()) walk(full);
            else if (entry.isFile()) {
              try {
                const lines = fs.readFileSync(full, "utf-8").split("\n");
                lines.forEach((line, i) => {
                  if (regex.test(line)) {
                    matches.push(`${path.relative(workspace, full)}:${i + 1}:${line}`);
                  }
                });
              } catch { /* skip binary/unreadable */ }
            }
            if (matches.length >= 100) break;
          }
        }

        walk(base);
        return { pattern: args.pattern, matches, count: matches.length };
      },
    },

    list_files: {
      name: "list_files",
      description: "List files in the workspace.",
      parameters: {
        type: "object",
        properties: {
          path: { type: "string" },
          max_results: { type: "integer" },
        },
      },
      async execute(args) {
        const base = args.path ? resolvePath(workspace, args.path as string) : workspace;
        const max = (args.max_results as number) || 200;
        const entries: string[] = [];

        function walk(dir: string) {
          if (entries.length >= max) return;
          for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            if (entry.name === ".git" || entry.name === "node_modules") continue;
            const full = path.join(dir, entry.name);
            if (entry.isDirectory()) walk(full);
            else entries.push(path.relative(workspace, full));
            if (entries.length >= max) break;
          }
        }

        walk(base);
        return { path: args.path || ".", entries: entries.sort(), count: entries.length };
      },
    },

    shell: {
      name: "shell",
      description: "Execute a shell command in the workspace.",
      parameters: {
        type: "object",
        properties: {
          command: { type: "string" },
          timeout: { type: "integer" },
        },
        required: ["command"],
      },
      async execute(args) {
        const command = (args.command as string).trim();
        if (BLOCKED_SHELL.some((p) => p.test(command))) {
          return { error: "Command blocked for safety" };
        }
        const timeout = (args.timeout as number) || getConfig().shellTimeout;
        try {
          const { stdout, stderr } = await execAsync(command, {
            cwd: workspace,
            timeout: timeout * 1000,
            maxBuffer: 50_000,
          });
          return { command, exit_code: 0, stdout, stderr };
        } catch (err: unknown) {
          const e = err as { code?: number; stdout?: string; stderr?: string; killed?: boolean };
          if (e.killed) return { error: `Command timed out after ${timeout}s`, command };
          return { command, exit_code: e.code ?? 1, stdout: e.stdout || "", stderr: e.stderr || "" };
        }
      },
    },
  };
}

export function toolDefinitions(workspace: string): ToolDefinition[] {
  const all = createTools(workspace);
  return getConfig().allowedTools.filter((n) => all[n]).map((n) => ({
    name: all[n].name,
    description: all[n].description,
    parameters: all[n].parameters,
  }));
}

export async function executeTool(
  name: string,
  args: Record<string, unknown>,
  workspace: string
): Promise<Record<string, unknown>> {
  const all = createTools(workspace);
  if (!getConfig().allowedTools.includes(name)) return { error: `Tool not allowed: ${name}` };
  const tool = all[name];
  if (!tool) return { error: `Unknown tool: ${name}` };
  try {
    return await tool.execute(args);
  } catch (err: unknown) {
    return { error: err instanceof Error ? err.message : String(err) };
  }
}
