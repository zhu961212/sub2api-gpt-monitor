#!/usr/bin/env python3
"""导出并验证官方 0.2.16 的智商恢复取票源码补丁。仅使用 Python 标准库。"""

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "源码" / "sub2api-host-0.2.16"
BASE = "01842576b3d5c1e2545b5a99ad555d36e28ed306"
OUTPUT = ROOT / "sub2api-gpt-monitor.patch"
SCOPE = ("backend", "frontend", "deploy/.env.example", "deploy/config.example.yaml")


def git(*args, index=None, data=None):
    env = os.environ.copy()
    if index is not None:
        env["GIT_INDEX_FILE"] = str(index)
    env["GIT_OPTIONAL_LOCKS"] = "0"
    result = subprocess.run(
        ["git", "-c", "core.splitIndex=false", *args],
        cwd=SOURCE, env=env, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if result.returncode:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"Git 操作失败：{' '.join(args)}\n{detail}")
    return result.stdout


def main():
    if not SOURCE.is_dir():
        raise RuntimeError(f"找不到源码目录：{SOURCE}")
    top = Path(git("rev-parse", "--show-toplevel").decode("utf-8").strip()).resolve()
    if top != SOURCE.resolve():
        raise RuntimeError("源码目录必须是独立 Git 仓库的根目录")
    head = git("rev-parse", "HEAD").decode("ascii").strip()
    if head != BASE:
        raise RuntimeError(f"基线不匹配：要求 {BASE}，当前 {head}")

    with tempfile.TemporaryDirectory(prefix="sub2api-patch-") as temporary:
        export_index = Path(temporary) / "export.index"
        verify_index = Path(temporary) / "verify.index"
        git("read-tree", BASE, index=export_index)
        git("add", "-A", "--", *SCOPE, index=export_index)
        forbidden = git(
            "diff", "--cached", "--name-only", "-z", BASE, "--",
            "backend/ent", "backend/migrations", index=export_index,
        )
        if forbidden:
            names = forbidden.decode("utf-8", errors="replace").rstrip("\0").replace("\0", "\n")
            raise RuntimeError(f"检测到数据库模型或迁移变更，已停止导出：\n{names}")
        patch = git(
            "diff", "--cached", "--binary", "--no-ext-diff",
            "--no-textconv", "--full-index", BASE, index=export_index,
        )
        if not patch:
            raise RuntimeError("没有可导出的源码补丁")
        expected_tree = git("write-tree", index=export_index)
        git("read-tree", BASE, index=verify_index)
        git("apply", "--cached", "--check", "--whitespace=nowarn", index=verify_index, data=patch)
        git("apply", "--cached", "--whitespace=nowarn", index=verify_index, data=patch)
        if git("write-tree", index=verify_index) != expected_tree:
            raise RuntimeError("补丁应用后的源码树不一致，已停止导出")

    temporary_output = None
    try:
        with tempfile.NamedTemporaryFile(prefix=".sub2api-patch-", suffix=".tmp", dir=ROOT, delete=False) as handle:
            temporary_output = Path(handle.name)
            handle.write(patch)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_output, OUTPUT)
    finally:
        if temporary_output is not None:
            temporary_output.unlink(missing_ok=True)

    print("验证通过：补丁可应用于官方 0.2.16，源码树一致。")
    print(f"文件：{OUTPUT.name}（{len(patch):,} 字节）")
    print(f"SHA256：{hashlib.sha256(patch).hexdigest()}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f"导出失败：{error}", file=sys.stderr)
        sys.exit(1)
