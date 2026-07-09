"""AI coding agent with tool-calling loop."""

from __future__ import annotations

import json
import uuid
from pathlib import Path
from typing import Any, Callable, Optional

from rails_ai_build.client import RemoteClient
from rails_ai_build.config import configure, get_config
from rails_ai_build.providers import get_provider
from rails_ai_build.tools import build_tools, execute_tool, tool_definitions

DEFAULT_SYSTEM = """You are an AI coding agent integrated via rails_ai_build.
You can read, search, and modify files in the project workspace using tools.
Follow existing code conventions. Make minimal, focused changes."""


class Agent:
    def __init__(
        self,
        provider: Optional[str] = None,
        model: Optional[str] = None,
        system_prompt: Optional[str] = None,
        workspace: Optional[Path | str] = None,
        remote: bool = False,
    ):
        self.provider_name = provider or get_config().default_provider
        self.model = model or get_config().default_model
        self.system_prompt = system_prompt or DEFAULT_SYSTEM
        self.workspace = Path(workspace) if workspace else get_config().workspace_root
        self.remote = remote or bool(get_config().remote_url)
        self.messages: list[dict] = [{"role": "system", "content": self.system_prompt}]
        self._callbacks: dict[str, list[Callable]] = {
            "on_tool_call": [],
            "on_iteration": [],
            "on_complete": [],
        }

        if not self.remote:
            self.provider = get_provider(self.provider_name)
            self.tools = build_tools(self.workspace)

    def on(self, event: str, callback: Callable) -> "Agent":
        if event in self._callbacks:
            self._callbacks[event].append(callback)
        return self

    def chat(self, user_message: str) -> dict[str, Any]:
        if self.remote:
            client = RemoteClient()
            return client.chat(
                user_message,
                provider=self.provider_name,
                model=self.model,
                system_prompt=self.system_prompt,
                workspace=str(self.workspace),
            )

        self.messages.append({"role": "user", "content": user_message})
        return self._run_loop()

    def _run_loop(self) -> dict[str, Any]:
        max_iter = get_config().max_iterations
        last_response = {}

        for iteration in range(1, max_iter + 1):
            response = self.provider.chat(
                self.messages,
                tool_definitions(),
                self.model,
            )
            last_response = response

            for cb in self._callbacks["on_iteration"]:
                cb(response)

            tool_calls = response.get("tool_calls") or []
            assistant_msg: dict[str, Any] = {
                "role": "assistant",
                "content": response.get("content"),
            }
            if tool_calls:
                assistant_msg["tool_calls"] = tool_calls
            self.messages.append(assistant_msg)

            if not tool_calls:
                break

            for tc in tool_calls:
                for cb in self._callbacks["on_tool_call"]:
                    cb(tc)
                result = execute_tool(tc["name"], tc["arguments"], self.workspace)
                self.messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc["id"],
                        "content": json.dumps(result, indent=2),
                    }
                )
        else:
            raise RuntimeError(f"Max iterations ({max_iter}) exceeded")

        for cb in self._callbacks["on_complete"]:
            cb(last_response)

        return {
            "content": last_response.get("content"),
            "iterations": iteration,
            "messages": self.messages,
            "usage": last_response.get("usage"),
            "finish_reason": last_response.get("finish_reason"),
        }
