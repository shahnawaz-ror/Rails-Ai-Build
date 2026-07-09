"""Agent tools for codebase interaction."""

from __future__ import annotations

import json
import re
import subprocess
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any

from rails_ai_build.config import get_config

BLOCKED_SHELL = [
    r"\brm\s+-rf\s+/\b",
    r"\bmkfs\b",
    r"\bdd\s+if=",
]


class BaseTool(ABC):
    name: str = ""
    description: str = ""
    parameters: dict = {}

    def __init__(self, workspace: Path):
        self.workspace = workspace.resolve()

    def definition(self) -> dict:
        return {
            "name": self.name,
            "description": self.description,
            "parameters": self.parameters,
        }

    def resolve_path(self, path: str) -> Path:
        full = (self.workspace / path.lstrip("/")).resolve()
        if not str(full).startswith(str(self.workspace)):
            raise PermissionError(f"Path escapes workspace: {path}")
        return full

    @abstractmethod
    def execute(self, args: dict[str, Any]) -> dict[str, Any]:
        ...


class ReadFileTool(BaseTool):
    name = "read_file"
    description = "Read the contents of a file in the workspace."
    parameters = {
        "type": "object",
        "properties": {
            "path": {"type": "string"},
            "offset": {"type": "integer"},
            "limit": {"type": "integer"},
        },
        "required": ["path"],
    }

    def execute(self, args):
        path = self.resolve_path(args["path"])
        if not path.is_file():
            return {"error": f"File not found: {args['path']}"}
        lines = path.read_text().splitlines()
        offset = max((args.get("offset") or 1) - 1, 0)
        limit = args.get("limit")
        selected = lines[offset : offset + limit] if limit else lines[offset:]
        numbered = [f"{offset + i + 1}|{line}" for i, line in enumerate(selected)]
        return {"path": args["path"], "content": "\n".join(numbered), "total_lines": len(lines)}


class WriteFileTool(BaseTool):
    name = "write_file"
    description = "Create or overwrite a file in the workspace."
    parameters = {
        "type": "object",
        "properties": {
            "path": {"type": "string"},
            "content": {"type": "string"},
        },
        "required": ["path", "content"],
    }

    def execute(self, args):
        path = self.resolve_path(args["path"])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(args["content"])
        return {"path": args["path"], "bytes_written": len(args["content"]), "status": "written"}


class GrepTool(BaseTool):
    name = "grep"
    description = "Search for a pattern in workspace files."
    parameters = {
        "type": "object",
        "properties": {
            "pattern": {"type": "string"},
            "path": {"type": "string"},
            "glob": {"type": "string"},
            "case_insensitive": {"type": "boolean"},
        },
        "required": ["pattern"],
    }

    def execute(self, args):
        pattern = args["pattern"]
        flags = re.IGNORECASE if args.get("case_insensitive") else 0
        regex = re.compile(pattern, flags)
        base = self.resolve_path(args["path"]) if args.get("path") else self.workspace
        glob = args.get("glob", "**/*")
        matches = []

        for file in base.glob(glob):
            if not file.is_file() or "/.git/" in str(file):
                continue
            try:
                for i, line in enumerate(file.read_text().splitlines(), 1):
                    if regex.search(line):
                        rel = file.relative_to(self.workspace)
                        matches.append(f"{rel}:{i}:{line}")
                        if len(matches) >= 100:
                            break
            except (UnicodeDecodeError, PermissionError):
                continue
            if len(matches) >= 100:
                break

        return {"pattern": pattern, "matches": matches, "count": len(matches)}


class ListFilesTool(BaseTool):
    name = "list_files"
    description = "List files and directories in the workspace."
    parameters = {
        "type": "object",
        "properties": {
            "path": {"type": "string"},
            "glob": {"type": "string"},
            "max_results": {"type": "integer"},
        },
    }

    def execute(self, args):
        base = self.resolve_path(args["path"]) if args.get("path") else self.workspace
        glob = args.get("glob", "**/*")
        max_results = args.get("max_results", 200)
        entries = sorted(
            str(p.relative_to(self.workspace))
            for p in base.glob(glob)
            if p.is_file() and "/.git/" not in str(p)
        )[:max_results]
        return {"path": args.get("path", "."), "entries": entries, "count": len(entries)}


class ShellTool(BaseTool):
    name = "shell"
    description = "Execute a shell command in the workspace."
    parameters = {
        "type": "object",
        "properties": {
            "command": {"type": "string"},
            "timeout": {"type": "integer"},
        },
        "required": ["command"],
    }

    def execute(self, args):
        command = args["command"].strip()
        for pattern in BLOCKED_SHELL:
            if re.search(pattern, command):
                return {"error": "Command blocked for safety"}
        timeout = args.get("timeout") or get_config().shell_timeout
        try:
            result = subprocess.run(
                command,
                shell=True,
                cwd=str(self.workspace),
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            return {
                "command": command,
                "exit_code": result.returncode,
                "stdout": result.stdout[:50_000],
                "stderr": result.stderr[:10_000],
            }
        except subprocess.TimeoutExpired:
            return {"error": f"Command timed out after {timeout}s", "command": command}


TOOLS: dict[str, type[BaseTool]] = {
    "read_file": ReadFileTool,
    "write_file": WriteFileTool,
    "grep": GrepTool,
    "list_files": ListFilesTool,
    "shell": ShellTool,
}


def build_tools(workspace: Path) -> dict[str, BaseTool]:
    allowed = get_config().allowed_tools
    return {name: TOOLS[name](workspace) for name in allowed if name in TOOLS}


def tool_definitions() -> list[dict]:
    workspace = get_config().workspace_root
    return [build_tools(workspace)[name].definition() for name in get_config().allowed_tools if name in TOOLS]


def execute_tool(name: str, arguments: dict, workspace: Path) -> dict:
    if name not in get_config().allowed_tools:
        return {"error": f"Tool not allowed: {name}"}
    tool = TOOLS[name](workspace)
    try:
        return tool.execute(arguments)
    except Exception as e:
        return {"error": str(e)}
