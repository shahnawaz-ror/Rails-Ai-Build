"""Model provider abstractions."""

from __future__ import annotations

import json
from abc import ABC, abstractmethod
from typing import Any, Optional

import httpx

from rails_ai_build.config import get_config


class BaseProvider(ABC):
    name: str = "base"

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or get_config().api_keys.get(self.name, "")

    @abstractmethod
    def chat(
        self,
        messages: list[dict],
        tools: list[dict],
        model: str,
        **kwargs,
    ) -> dict[str, Any]:
        ...


class OpenAIProvider(BaseProvider):
    name = "openai"
    BASE_URL = "https://api.openai.com/v1"

    def chat(self, messages, tools, model, **kwargs):
        payload: dict[str, Any] = {
            "model": model,
            "messages": self._format_messages(messages),
        }
        if tools:
            payload["tools"] = [
                {
                    "type": "function",
                    "function": {
                        "name": t["name"],
                        "description": t["description"],
                        "parameters": t["parameters"],
                    },
                }
                for t in tools
            ]

        with httpx.Client(timeout=120) as client:
            response = client.post(
                f"{self.BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json=payload,
            )
            response.raise_for_status()
            return self._parse(response.json())

    def _format_messages(self, messages):
        result = []
        for msg in messages:
            entry: dict[str, Any] = {"role": msg["role"], "content": msg.get("content")}
            if msg.get("tool_calls"):
                entry["tool_calls"] = [
                    {
                        "id": tc["id"],
                        "type": "function",
                        "function": {
                            "name": tc["name"],
                            "arguments": json.dumps(tc["arguments"]),
                        },
                    }
                    for tc in msg["tool_calls"]
                ]
            if msg.get("tool_call_id"):
                entry["tool_call_id"] = msg["tool_call_id"]
            result.append(entry)
        return result

    def _parse(self, body):
        choice = body["choices"][0]
        message = choice["message"]
        tool_calls = []
        for tc in message.get("tool_calls") or []:
            tool_calls.append(
                {
                    "id": tc["id"],
                    "name": tc["function"]["name"],
                    "arguments": json.loads(tc["function"]["arguments"]),
                }
            )
        return {
            "role": "assistant",
            "content": message.get("content"),
            "tool_calls": tool_calls,
            "finish_reason": choice.get("finish_reason"),
            "usage": body.get("usage"),
        }


class AnthropicProvider(BaseProvider):
    name = "anthropic"
    BASE_URL = "https://api.anthropic.com/v1"
    VERSION = "2023-06-01"

    def chat(self, messages, tools, model, **kwargs):
        system, conversation = self._split_system(messages)
        payload: dict[str, Any] = {
            "model": model,
            "max_tokens": kwargs.get("max_tokens", 4096),
            "messages": self._format_messages(conversation),
        }
        if system:
            payload["system"] = system
        if tools:
            payload["tools"] = [
                {
                    "name": t["name"],
                    "description": t["description"],
                    "input_schema": t["parameters"],
                }
                for t in tools
            ]

        with httpx.Client(timeout=120) as client:
            response = client.post(
                f"{self.BASE_URL}/messages",
                headers={
                    "x-api-key": self.api_key,
                    "anthropic-version": self.VERSION,
                },
                json=payload,
            )
            response.raise_for_status()
            return self._parse(response.json())

    def _split_system(self, messages):
        system_parts, conversation = [], []
        for msg in messages:
            if msg["role"] == "system":
                system_parts.append(msg["content"])
            else:
                conversation.append(msg)
        return "\n\n".join(system_parts) or None, conversation

    def _format_messages(self, messages):
        result = []
        for msg in messages:
            role = "user" if msg["role"] == "tool" else msg["role"]
            entry: dict[str, Any] = {"role": role}
            if msg.get("tool_calls"):
                entry["content"] = [
                    {
                        "type": "tool_use",
                        "id": tc["id"],
                        "name": tc["name"],
                        "input": tc["arguments"],
                    }
                    for tc in msg["tool_calls"]
                ]
            elif msg.get("tool_call_id"):
                entry["content"] = [
                    {
                        "type": "tool_result",
                        "tool_use_id": msg["tool_call_id"],
                        "content": str(msg.get("content", "")),
                    }
                ]
            else:
                entry["content"] = msg.get("content", "")
            result.append(entry)
        return result

    def _parse(self, body):
        text_parts, tool_calls = [], []
        for block in body.get("content", []):
            if block["type"] == "text":
                text_parts.append(block["text"])
            elif block["type"] == "tool_use":
                tool_calls.append(
                    {
                        "id": block["id"],
                        "name": block["name"],
                        "arguments": block.get("input", {}),
                    }
                )
        return {
            "role": "assistant",
            "content": "\n".join(text_parts) or None,
            "tool_calls": tool_calls,
            "finish_reason": body.get("stop_reason"),
            "usage": body.get("usage"),
        }


PROVIDERS: dict[str, type[BaseProvider]] = {
    "openai": OpenAIProvider,
    "anthropic": AnthropicProvider,
}


def get_provider(name: str, api_key: Optional[str] = None) -> BaseProvider:
    cls = PROVIDERS.get(name)
    if not cls:
        raise ValueError(f"Unknown provider: {name}")
    return cls(api_key=api_key)
