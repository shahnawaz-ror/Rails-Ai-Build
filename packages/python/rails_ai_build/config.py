"""Configuration for rails_ai_build Python SDK."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional


@dataclass
class Config:
    default_provider: str = "openai"
    default_model: str = "gpt-4o"
    api_keys: dict[str, str] = field(default_factory=dict)
    workspace_root: Path = field(default_factory=lambda: Path.cwd())
    max_iterations: int = 25
    shell_timeout: int = 30
    allowed_tools: list[str] = field(
        default_factory=lambda: ["read_file", "write_file", "grep", "list_files", "shell"]
    )
    remote_url: Optional[str] = None  # If set, delegate to HTTP server


_config = Config()


def configure(**kwargs) -> Config:
    global _config
    for key, value in kwargs.items():
        if hasattr(_config, key):
            if key == "workspace_root":
                value = Path(value)
            setattr(_config, key, value)
    return _config


def get_config() -> Config:
    return _config
