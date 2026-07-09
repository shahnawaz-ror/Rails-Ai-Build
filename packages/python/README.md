# rails-ai-build (Python)

Cursor-like AI coding agents for any Python project. Works standalone or connects to a remote server.

## Install

```bash
pip install rails-ai-build
# or from monorepo:
pip install -e packages/python
```

## Standalone usage (no Ruby/Rails required)

```python
from rails_ai_build import configure, ask

configure(
    api_keys={"openai": "sk-..."},
    default_model="gpt-4o",
    workspace_root=".",
)

result = ask("Add type hints to all functions in src/")
print(result["content"])
```

## Full agent with callbacks

```python
from rails_ai_build import Agent

agent = Agent(provider="anthropic", model="claude-sonnet-4-20250514")
agent.on("on_tool_call", lambda tc: print(f"Tool: {tc['name']}"))
result = agent.chat("Create a FastAPI health endpoint")
```

## Remote mode (connect to Rails engine or standalone server)

```python
from rails_ai_build import configure, ask

configure(remote_url="http://localhost:9292")
result = ask("List all Python files in the project")
```

## CLI

```bash
export OPENAI_API_KEY=sk-...
rails-ai-build "Add docstrings to all modules in src/"
rails-ai-build --remote http://localhost:9292 --list-providers
```
