import { RemoteClient } from "./client.js";
import { configure, getConfig } from "./config.js";
import { getProvider, type Message, type ToolCall } from "./providers.js";
import { executeTool, toolDefinitions } from "./tools.js";

const DEFAULT_SYSTEM = `You are an AI coding agent integrated via rails_ai_build.
You can read, search, and modify files in the project workspace using tools.
Follow existing code conventions. Make minimal, focused changes.`;

export interface AgentOptions {
  provider?: string;
  model?: string;
  systemPrompt?: string;
  workspace?: string;
  remote?: boolean;
}

export type AgentCallback = (data: unknown) => void;

export class Agent {
  private providerName: string;
  private model: string;
  private systemPrompt: string;
  private workspace: string;
  private remote: boolean;
  private messages: Message[] = [];
  private callbacks: Record<string, AgentCallback[]> = {
    on_tool_call: [],
    on_iteration: [],
    on_complete: [],
  };

  constructor(options: AgentOptions = {}) {
    this.providerName = options.provider || getConfig().defaultProvider;
    this.model = options.model || getConfig().defaultModel;
    this.systemPrompt = options.systemPrompt || DEFAULT_SYSTEM;
    this.workspace = options.workspace || getConfig().workspaceRoot;
    this.remote = options.remote || Boolean(getConfig().remoteUrl);
    this.messages = [{ role: "system", content: this.systemPrompt }];
  }

  on(event: string, callback: AgentCallback): this {
    this.callbacks[event]?.push(callback);
    return this;
  }

  async chat(userMessage: string) {
    if (this.remote) {
      const client = new RemoteClient();
      return client.chat(userMessage, {
        provider: this.providerName,
        model: this.model,
        systemPrompt: this.systemPrompt,
        workspace: this.workspace,
      });
    }

    this.messages.push({ role: "user", content: userMessage });
    return this.runLoop();
  }

  private async runLoop() {
    const provider = getProvider(this.providerName);
    const maxIter = getConfig().maxIterations;
    let lastResponse: Awaited<ReturnType<typeof provider.chat>> | undefined;
    let iteration = 0;

    for (iteration = 1; iteration <= maxIter; iteration++) {
      const response = await provider.chat(this.messages, toolDefinitions(this.workspace), this.model);
      lastResponse = response;
      this.callbacks.on_iteration.forEach((cb) => cb(response));

      const toolCalls = response.tool_calls || [];
      const assistantMsg: Message = { role: "assistant", content: response.content };
      if (toolCalls.length) assistantMsg.tool_calls = toolCalls;
      this.messages.push(assistantMsg);

      if (!toolCalls.length) break;

      for (const tc of toolCalls) {
        this.callbacks.on_tool_call.forEach((cb) => cb(tc));
        const result = await executeTool(tc.name, tc.arguments, this.workspace);
        this.messages.push({
          role: "tool",
          tool_call_id: tc.id,
          content: JSON.stringify(result, null, 2),
        });
      }
    }

    if (iteration > maxIter) throw new Error(`Max iterations (${maxIter}) exceeded`);

    this.callbacks.on_complete.forEach((cb) => cb(lastResponse));

    return {
      content: lastResponse?.content,
      iterations: iteration,
      messages: this.messages,
      usage: lastResponse?.usage,
      finish_reason: lastResponse?.finish_reason,
    };
  }
}

export async function ask(prompt: string, options: AgentOptions = {}) {
  const agent = new Agent(options);
  return agent.chat(prompt);
}

export { configure, getConfig };
