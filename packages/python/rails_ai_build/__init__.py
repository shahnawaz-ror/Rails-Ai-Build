"""Rails AI Build — Cursor-like AI coding agents for Python."""

from rails_ai_build.agent import Agent
from rails_ai_build.client import RemoteClient
from rails_ai_build.config import configure, get_config

__version__ = "1.0.0"
__all__ = ["Agent", "RemoteClient", "configure", "get_config", "ask"]


def ask(prompt: str, **kwargs):
    """One-shot agent prompt."""
    return Agent(**kwargs).chat(prompt)
