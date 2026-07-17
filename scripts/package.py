#!/usr/bin/env python3
"""本地手工打包(不经 CI):按 .pkgmeta 的 ignore 列表复制仓库,替换 @project-version@,产出 zip。

用法: python3 scripts/package.py v0.1.0
产物: dist/SettingsHub-<版本>.zip(解压即得 SettingsHub/ 目录,放进 Interface/AddOns/)
"""
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "SettingsHub"


def pkgmeta_ignores():
    ignores = []
    in_ignore = False
    for line in (ROOT / ".pkgmeta").read_text().splitlines():
        if line.strip() == "ignore:":
            in_ignore = True
        elif in_ignore and line.strip().startswith("- "):
            ignores.append(line.strip()[2:])
        elif in_ignore and line.strip() and not line.startswith(" ") and not line.startswith("\t"):
            in_ignore = False
    return ignores


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    version = sys.argv[1]
    ignores = set(pkgmeta_ignores()) | {".git", ".github", "dist", "dumps", ".pkgmeta"}

    dist = ROOT / "dist"
    stage = dist / ADDON
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)

    copied = 0
    for path in ROOT.rglob("*"):
        rel = path.relative_to(ROOT)
        if not path.is_file():
            continue
        if rel.parts[0] in ignores or any(p.startswith(".") for p in rel.parts):
            continue
        dest = stage / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if rel.name == f"{ADDON}.toc":
            dest.write_text(path.read_text().replace("@project-version@", version))
        else:
            shutil.copy2(path, dest)
        copied += 1

    zip_path = dist / f"{ADDON}-{version}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(stage.rglob("*")):
            if f.is_file():
                zf.write(f, f.relative_to(dist))
    print(f"{copied} 个文件 -> {zip_path}({zip_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
