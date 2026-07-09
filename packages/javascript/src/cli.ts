#!/usr/bin/env node
import { ask, configure } from "./index.js";
import { RemoteClient } from "./client.js";

const args = process.argv.slice(2);
const flags: Record<string, string | boolean> = {};
const positional: string[] = [];

for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--")) {
    const key = args[i].slice(2);
    const next = args[i + 1];
    if (next && !next.startsWith("--")) {
      flags[key] = next;
      i++;
    } else {
      flags[key] = true;
    }
  } else {
    positional.push(args[i]);
  }
}

configure({
  defaultProvider: (flags.provider as string) || "openai",
  defaultModel: (flags.model as string) || "gpt-4o",
  workspaceRoot: (flags.workspace as string) || process.cwd(),
  remoteUrl: flags.remote as string | undefined,
  apiKeys: {
    openai: process.env.OPENAI_API_KEY || "",
    anthropic: process.env.ANTHROPIC_API_KEY || "",
  },
});

if (flags["list-providers"]) {
  const client = new RemoteClient(flags.remote as string);
  console.log(JSON.stringify(await client.listProviders(), null, 2));
  process.exit(0);
}

if (flags.version) {
  console.log("0.2.0");
  process.exit(0);
}

const prompt = positional.join(" ");
if (!prompt) {
  console.log(`Usage: rails-ai-build [options] "your prompt"

Options:
  --provider <name>    openai | anthropic (default: openai)
  --model <name>       Model name
  --workspace <path>   Project root (default: cwd)
  --remote <url>       Use remote server instead of local agent
  --list-providers     List providers on remote server
  --version            Show version`);
  process.exit(1);
}

const result = await ask(prompt, {
  provider: flags.provider as string,
  model: flags.model as string,
  remote: Boolean(flags.remote),
});

console.log(result.content || JSON.stringify(result, null, 2));
