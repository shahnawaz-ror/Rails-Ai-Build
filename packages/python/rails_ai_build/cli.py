"""CLI for rails_ai_build Python SDK."""

from __future__ import annotations

import argparse
import os
import sys

from rails_ai_build import __version__, ask, configure
from rails_ai_build.client import RemoteClient


def main():
    parser = argparse.ArgumentParser(description="Rails AI Build — AI coding agent CLI")
    parser.add_argument("prompt", nargs="?", help="Prompt to send to the agent")
    parser.add_argument("--provider", default="openai", help="AI provider (openai, anthropic)")
    parser.add_argument("--model", help="Model name")
    parser.add_argument("--workspace", default=".", help="Project workspace root")
    parser.add_argument("--remote", help="Remote server URL (skip local agent)")
    parser.add_argument("--list-providers", action="store_true", help="List remote providers")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")

    args = parser.parse_args()

    configure(
        default_provider=args.provider,
        default_model=args.model or "gpt-4o",
        workspace_root=args.workspace,
        remote_url=args.remote,
        api_keys={
            "openai": os.environ.get("OPENAI_API_KEY", ""),
            "anthropic": os.environ.get("ANTHROPIC_API_KEY", ""),
        },
    )

    if args.list_providers:
        client = RemoteClient(args.remote)
        print(client.list_providers())
        return

    if not args.prompt:
        parser.print_help()
        sys.exit(1)

    result = ask(args.prompt, provider=args.provider, model=args.model, remote=bool(args.remote))
    print(result.get("content", result))


if __name__ == "__main__":
    main()
