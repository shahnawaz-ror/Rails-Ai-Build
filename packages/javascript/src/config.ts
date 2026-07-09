export interface Config {
  defaultProvider: string;
  defaultModel: string;
  apiKeys: Record<string, string>;
  workspaceRoot: string;
  maxIterations: number;
  shellTimeout: number;
  allowedTools: string[];
  remoteUrl?: string;
}

const config: Config = {
  defaultProvider: "openai",
  defaultModel: "gpt-4o",
  apiKeys: {},
  workspaceRoot: process.cwd(),
  maxIterations: 25,
  shellTimeout: 30,
  allowedTools: ["read_file", "write_file", "grep", "list_files", "shell"],
};

export function configure(overrides: Partial<Config>): Config {
  Object.assign(config, overrides);
  return config;
}

export function getConfig(): Config {
  return config;
}
