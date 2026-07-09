import { getConfig } from "./config.js";

export interface Message {
  role: string;
  content?: string | null;
  tool_calls?: ToolCall[];
  tool_call_id?: string;
}

export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

export interface ProviderResponse {
  role: string;
  content?: string | null;
  tool_calls: ToolCall[];
  finish_reason?: string;
  usage?: Record<string, unknown>;
}

export interface Provider {
  name: string;
  chat(messages: Message[], tools: ToolDefinition[], model: string): Promise<ProviderResponse>;
}

export interface ToolDefinition {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
}

export class OpenAIProvider implements Provider {
  name = "openai";

  async chat(messages: Message[], tools: ToolDefinition[], model: string): Promise<ProviderResponse> {
    const apiKey = getConfig().apiKeys.openai;
    if (!apiKey) throw new Error("OpenAI API key not configured");

    const body: Record<string, unknown> = {
      model,
      messages: messages.map((m) => {
        const entry: Record<string, unknown> = { role: m.role, content: m.content };
        if (m.tool_calls) {
          entry.tool_calls = m.tool_calls.map((tc) => ({
            id: tc.id,
            type: "function",
            function: { name: tc.name, arguments: JSON.stringify(tc.arguments) },
          }));
        }
        if (m.tool_call_id) entry.tool_call_id = m.tool_call_id;
        return entry;
      }),
    };

    if (tools.length) {
      body.tools = tools.map((t) => ({
        type: "function",
        function: { name: t.name, description: t.description, parameters: t.parameters },
      }));
    }

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    const data = await response.json();
    if (!response.ok) throw new Error(data.error?.message || `OpenAI error ${response.status}`);

    const choice = data.choices[0];
    const message = choice.message;
    const tool_calls = (message.tool_calls || []).map((tc: { id: string; function: { name: string; arguments: string } }) => ({
      id: tc.id,
      name: tc.function.name,
      arguments: JSON.parse(tc.function.arguments),
    }));

    return {
      role: "assistant",
      content: message.content,
      tool_calls,
      finish_reason: choice.finish_reason,
      usage: data.usage,
    };
  }
}

export class AnthropicProvider implements Provider {
  name = "anthropic";

  async chat(messages: Message[], tools: ToolDefinition[], model: string): Promise<ProviderResponse> {
    const apiKey = getConfig().apiKeys.anthropic;
    if (!apiKey) throw new Error("Anthropic API key not configured");

    const systemParts: string[] = [];
    const conversation: Message[] = [];
    for (const m of messages) {
      if (m.role === "system") systemParts.push(m.content || "");
      else conversation.push(m);
    }

    const body: Record<string, unknown> = {
      model,
      max_tokens: 4096,
      messages: conversation.map((m) => {
        const role = m.role === "tool" ? "user" : m.role;
        if (m.tool_calls) {
          return {
            role,
            content: m.tool_calls.map((tc) => ({
              type: "tool_use",
              id: tc.id,
              name: tc.name,
              input: tc.arguments,
            })),
          };
        }
        if (m.tool_call_id) {
          return {
            role,
            content: [{ type: "tool_result", tool_use_id: m.tool_call_id, content: m.content || "" }],
          };
        }
        return { role, content: m.content || "" };
      }),
    };

    if (systemParts.length) body.system = systemParts.join("\n\n");
    if (tools.length) {
      body.tools = tools.map((t) => ({
        name: t.name,
        description: t.description,
        input_schema: t.parameters,
      }));
    }

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    const data = await response.json();
    if (!response.ok) throw new Error(data.error?.message || `Anthropic error ${response.status}`);

    const textParts: string[] = [];
    const tool_calls: ToolCall[] = [];
    for (const block of data.content || []) {
      if (block.type === "text") textParts.push(block.text);
      else if (block.type === "tool_use") {
        tool_calls.push({ id: block.id, name: block.name, arguments: block.input || {} });
      }
    }

    return {
      role: "assistant",
      content: textParts.join("\n") || null,
      tool_calls,
      finish_reason: data.stop_reason,
      usage: data.usage,
    };
  }
}

const providers: Record<string, Provider> = {
  openai: new OpenAIProvider(),
  anthropic: new AnthropicProvider(),
};

export function getProvider(name: string): Provider {
  const provider = providers[name];
  if (!provider) throw new Error(`Unknown provider: ${name}`);
  return provider;
}
