import { getConfig } from "./config.js";

export interface ChatResult {
  content?: string;
  iterations?: number;
  usage?: Record<string, unknown>;
  finish_reason?: string;
  messages?: unknown[];
}

export class RemoteClient {
  constructor(
    private baseUrl?: string,
    private timeout = 300_000
  ) {
    this.baseUrl = (baseUrl || getConfig().remoteUrl || "http://localhost:9292").replace(/\/$/, "");
  }

  async chat(
    message: string,
    options: {
      provider?: string;
      model?: string;
      systemPrompt?: string;
      workspace?: string;
    } = {}
  ): Promise<ChatResult> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeout);

    const response = await fetch(`${this.baseUrl}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message,
        provider: options.provider,
        model: options.model,
        system_prompt: options.systemPrompt,
        workspace: options.workspace,
      }),
      signal: controller.signal,
    });

    clearTimeout(timer);

    if (!response.ok) {
      const err = await response.json().catch(() => ({}));
      throw new Error((err as { error?: string }).error || `HTTP ${response.status}`);
    }

    return response.json() as Promise<ChatResult>;
  }

  async listProviders(): Promise<unknown> {
    const response = await fetch(`${this.baseUrl}/models/providers`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  }

  async health(): Promise<unknown> {
    const response = await fetch(`${this.baseUrl}/health`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  }
}
