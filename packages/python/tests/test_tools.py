"""Tests for rails_ai_build Python SDK."""

import tempfile
from pathlib import Path

import pytest

from rails_ai_build.config import configure
from rails_ai_build.tools import ReadFileTool, WriteFileTool


@pytest.fixture
def workspace(tmp_path):
    configure(workspace_root=tmp_path)
    return tmp_path


def test_read_file(workspace):
    (workspace / "hello.py").write_text("print('hi')\n")
    tool = ReadFileTool(workspace)
    result = tool.execute({"path": "hello.py"})
    assert "1|print('hi')" in result["content"]


def test_write_file(workspace):
    tool = WriteFileTool(workspace)
    result = tool.execute({"path": "src/main.py", "content": "def main(): pass\n"})
    assert result["status"] == "written"
    assert (workspace / "src/main.py").exists()


def test_path_escape_blocked(workspace):
    tool = ReadFileTool(workspace)
    with pytest.raises(PermissionError):
        tool.execute({"path": "../../../etc/passwd"})
