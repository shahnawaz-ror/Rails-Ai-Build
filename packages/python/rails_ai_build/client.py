"""HTTP client for remote rails_ai_build server or Rails engine."""

from __future__ import annotations

import json
from typing import Any, Optional

import httpx

from rails_ai_build.config import get_config


class RemoteClient:
    """Talk to a rails_ai_build HTTP server from any language stack."""

    def __init__(self, base_url: Optional[str] = None, timeout: float = 300.0):
        self.base_url = (base_url or get_config().remote_url or "http://localhost:9292").rstrip("/")
        self.timeout = timeout

    def chat(
        self,
        message: str,
        *,
        provider: Optional[str] = None,
        model: Optional[str] = None,
        system_prompt: Optional[str] = None,
        workspace: Optional[str] = None,
    ) -> dict[str, Any]:
        payload = {"message": message}
        if provider:
            payload["provider"] = provider
        if model:
            payload["model"] = model
        if system_prompt:
            payload["system_prompt"] = system_prompt
        if workspace:
            payload["workspace"] = workspace

        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(f"{self.base_url}/chat", json=payload)
            response.raise_for_status()
            return response.json()

    def list_providers(self) -> dict[str, Any]:
        with httpx.Client(timeout=30) as client:
            response = client.get(f"{self.base_url}/models/providers")
            response.raise_for_status()
            return response.json()

    def health(self) -> dict[str, Any]:
        with httpx.Client(timeout=10) as client:
            response = client.get(f"{self.base_url}/health")
            response.raise_for_status()
            return response.json()
