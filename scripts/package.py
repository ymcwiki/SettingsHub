#!/usr/bin/env python3
"""本地手工打包(不经 CI):按 .pkgmeta 的 ignore 列表复制仓库,替换 @project-version@,产出 zip。

用法: python3 scripts/package.py v0.1.0
产物: dist/SettingsHub-<版本>.zip(解压即得 SettingsHub/ 目录,放进 Interface/AddOns/)
"""
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "SettingsHub"


def pkgmeta_ignores():
    ignores = []
    in_ignore = False
    for line in (ROOT / ".pkgmeta").read_text(encoding="utf-8").splitlines():
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
    dist.mkdir(parents=True, exist_ok=True)
    zip_path = dist / f"{ADDON}-{version}.zip"

    # Stage outside the Dropbox-backed repository. Sync clients can briefly
    # lock directories they are indexing, which made a second local build fail
    # while deleting the previous stage tree.
    with tempfile.TemporaryDirectory(prefix="settingshub-package-") as temp_dir:
        temp_root = Path(temp_dir)
        stage = temp_root / ADDON
        stage.mkdir()

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
                dest.write_text(
                    path.read_text(encoding="utf-8").replace("@project-version@", version),
                    encoding="utf-8",
                )
            else:
                shutil.copy2(path, dest)
            copied += 1

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for f in sorted(stage.rglob("*")):
                if f.is_file():
                    zf.write(f, f.relative_to(temp_root))

    # Cheap but useful release smoke test: catch an incorrectly rooted zip,
    # leaked development files, or an unreplaced version token before upload.
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        toc_name = f"{ADDON}/{ADDON}.toc"
        if toc_name not in names:
            raise RuntimeError(f"package missing {toc_name}")
        forbidden = (f"{ADDON}/docs/", f"{ADDON}/scripts/", f"{ADDON}/tests/", f"{ADDON}/.github/")
        leaked = sorted(name for name in names if name.startswith(forbidden))
        if leaked:
            raise RuntimeError(f"development files leaked into package: {leaked[0]}")
        toc = zf.read(toc_name).decode("utf-8-sig")
        if "@project-version@" in toc or f"## Version: {version}" not in toc:
            raise RuntimeError("package version token was not replaced")
    print(f"{copied} 个文件 -> {zip_path}({zip_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
