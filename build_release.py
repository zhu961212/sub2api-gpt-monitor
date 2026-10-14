#!/usr/bin/env python3
"""构建 Linux 发布包和完整源码 ZIP；不执行上传。"""

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import zipfile

from make_patch import BASE, ROOT, SOURCE

NAME = "intelligence-recovery-0.2.16-linux-v1"
DIST = SOURCE / "backend/internal/web/dist"
SCRIPTS = ("update.sh", "rollback.sh", "manage.sh", "common.sh")
ROOT_FILES = ("Dockerfile", "Dockerfile.goreleaser", "Makefile", "LICENSE",
              ".dockerignore", ".gitattributes", ".gitignore", ".goreleaser.yaml",
              ".goreleaser.simple.yaml", "README.md", "README_CN.md", "README_JA.md")


def run(args, cwd=SOURCE, env=None):
    subprocess.run([str(arg) for arg in args], cwd=cwd, env=env, check=True)


def write(path, value):
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(value)


def digest(path):
    with path.open("rb") as handle:
        result = hashlib.sha256()
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def sums(directory, filename):
    files = sorted(path for path in directory.rglob("*") if path.is_file() and path.name != filename)
    write(directory / filename, "".join(f"{digest(path)}  {path.relative_to(directory).as_posix()}\n" for path in files))


def source_zip(output):
    listing = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--",
         "backend", "frontend", "deploy", "docs/legal", *ROOT_FILES], cwd=SOURCE)
    names = {name.decode("utf-8") for name in listing.split(b"\0") if name}
    names.update(path.relative_to(SOURCE).as_posix() for path in DIST.rglob("*") if path.is_file())
    blocked = {".git", "node_modules", "__pycache__", ".gocache", ".cache", ".codex", ".dev", "data"}
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in sorted(names):
            relative, path = Path(name), SOURCE / name
            basename = relative.name.lower()
            if blocked.intersection(relative.parts) or name.startswith("deploy/gpt-account-monitor/"):
                continue
            if basename in {"config.yaml", "env.private", ".env"} or basename.endswith((".pyc", ".pyo")):
                continue
            if basename.startswith(".env.") and basename != ".env.example":
                continue
            if path.is_symlink() or not path.is_file():
                continue
            info = zipfile.ZipInfo(f"sub2api-host-0.2.16/{name}")
            info.create_system = 3
            info.external_attr = (0o100755 if basename.endswith(".sh") else 0o100644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-frontend", action="store_true", help="重新检查并构建前端；默认复用已验证 dist")
    args = parser.parse_args()
    required = [ROOT / "README.md", ROOT / "PROJECT.md", ROOT / "VALIDATION.txt", ROOT / "LICENSE", *(ROOT / "deploy" / name for name in SCRIPTS)]
    for path in required:
        if not path.is_file():
            raise RuntimeError(f"缺少发布文件：{path}")
    run([sys.executable, ROOT / "make_patch.py"], cwd=ROOT)
    if args.build_frontend:
        frontend = SOURCE / "frontend"
        for tool, arguments in (("vitest/vitest.mjs", ["run", "src/i18n/__tests__/localeKeyCompleteness.spec.ts"]),
                                ("vue-tsc/bin/vue-tsc.js", ["-b"]), ("vite/bin/vite.js", ["build"])):
            run(["node", frontend / "node_modules" / tool, *arguments], cwd=frontend)
    if not (DIST / "index.html").is_file() or not any((DIST / "assets").glob("*")):
        raise RuntimeError("缺少前端 dist，请先安装前端依赖并使用 --build-frontend")
    print("前端：" + ("已重新构建" if args.build_frontend else "复用已验证 dist"))
    release = ROOT / "release"
    release.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".build-", dir=release) as temporary:
        staging, package = Path(temporary), Path(temporary) / NAME
        package.mkdir()
        for arch, machine in (("amd64", 62), ("arm64", 183)):
            binary = package / "bin" / f"linux-{arch}" / "sub2api"
            binary.parent.mkdir(parents=True)
            env = dict(os.environ, CGO_ENABLED="0", GOOS="linux", GOARCH=arch)
            run(["go", "build", "-tags", "embed", "-trimpath", "-ldflags",
                 "-s -w -X main.Version=0.2.16 -X main.Commit=0184257-intelligence-recovery-v1 -X main.BuildType=release",
                 "-o", binary, "./cmd/server"], cwd=SOURCE / "backend", env=env)
            with binary.open("rb") as handle:
                header = handle.read(20)
            if len(header) != 20 or header[:6] != b"\x7fELF\x02\x01" or struct.unpack("<H", header[18:20])[0] != machine:
                raise RuntimeError(f"Linux {arch} 二进制头验证失败")
            print(f"Linux {arch} ELF64 验证通过")
        for path in required:
            shutil.copyfile(path, package / path.name)
        shutil.copyfile(ROOT / "sub2api-gpt-monitor.patch", package / "sub2api-gpt-monitor.patch")
        write(package / "UPSTREAM_BASE.txt", BASE + "\n")
        sums(package, "SHA256SUMS")
        def normalize(info):
            info.uid = info.gid = info.mtime = 0
            info.uname = info.gname = ""
            info.mode = 0o755 if info.isdir() or "/bin/" in info.name or info.name.endswith(".sh") else 0o644
            return info
        with tarfile.open(staging / "sub2api-0.2.16-gpt-monitor-linux.tar.gz", "w:gz") as archive:
            archive.add(package, arcname=NAME, filter=normalize)
        source_zip(staging / "sub2api-gpt-monitor-source.zip")
        with zipfile.ZipFile(staging / "sub2api-gpt-monitor-source.zip") as archive:
            if archive.testzip() is not None:
                raise RuntimeError("源码 ZIP 校验失败")
            if not any(name.startswith("sub2api-host-0.2.16/docs/legal/") for name in archive.namelist()):
                raise RuntimeError("源码 ZIP 缺少构建所需 docs/legal")
        with tarfile.open(staging / "sub2api-0.2.16-gpt-monitor-linux.tar.gz") as archive:
            for member in archive.getmembers():
                relative = Path(member.name).relative_to(NAME)
                if member.isfile():
                    if hashlib.sha256(archive.extractfile(member).read()).hexdigest() != digest(package / relative):
                        raise RuntimeError(f"安装包内容校验失败：{member.name}")
                    expected_mode = 0o755 if "bin" in relative.parts or member.name.endswith(".sh") else 0o644
                    if member.mode != expected_mode:
                        raise RuntimeError(f"安装包权限校验失败：{member.name}")
                elif not member.isdir():
                    raise RuntimeError(f"安装包包含非常规文件：{member.name}")
        for name in ("sub2api-gpt-monitor.patch", "README.md", "PROJECT.md", "VALIDATION.txt"):
            shutil.copyfile(ROOT / name, staging / name)
        assets = [path for path in staging.iterdir() if path.is_file()]
        write(staging / "SHA256SUMS.txt", "".join(f"{digest(path)}  {path.name}\n" for path in sorted(assets)))
        destination = release / NAME
        if destination.exists():
            if destination.resolve().parent != release.resolve():
                raise RuntimeError("发布目录解析到了 release 之外")
            os.replace(destination, staging / "previous")
        os.replace(package, destination)
        for path in assets + [staging / "SHA256SUMS.txt"]:
            os.replace(path, release / path.name)
    print(f"发布产物已写入：{release}，校验文件：SHA256SUMS.txt")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"构建失败：{error}", file=sys.stderr)
        sys.exit(1)
