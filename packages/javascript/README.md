# @rails-ai-build/sdk (JavaScript/TypeScript)

Cursor-like AI coding agents for Node.js. Works standalone or connects to a remote server.

## Install

```bash
npm install @rails-ai-build/sdk
# or from monorepo:
cd packages/javascript && npm install && npm run build
```

## Standalone usage (no Ruby/Rails required)

```typescript
import { configure, ask } from "@rails-ai-build/sdk";

configure({
  apiKeys: { openai: process.env.OPENAI_API_KEY! },
  defaultModel: "gpt-4o",
  workspaceRoot: ".",
});

const result = await ask("Add JSDoc comments to all exported functions in src/");
console.log(result.content);
```

## Full agent with callbacks

```typescript
import { Agent } from "@rails-ai-build/sdk";

const agent = new Agent({ provider: "anthropic", model: "claude-sonnet-4-20250514" });
agent.on("on_tool_call", (tc) => console.log("Tool:", (tc as { name: string }).name));
const result = await agent.chat("Create an Express health endpoint");
```

## Remote mode

```typescript
import { configure, ask } from "@rails-ai-build/sdk";

configure({ remoteUrl: "http://localhost:9292" });
const result = await ask("List all TypeScript files");
```

## CLI

```bash
export OPENAI_API_KEY=sk-...
npx rails-ai-build "Refactor utils.js to use async/await"
npx rails-ai-build --remote http://localhost:9292 --list-providers
```
