#!/usr/bin/env python3
"""L2 策展底稿:抓 warcraft.wiki.gg 逐补丁 API_changes 页,抽出 CVar 相关条目。

用法: python3 scripts/wiki_apichanges.py 12.1.0 [输出.md]

- {{apitooltip|type=cvar|...}} 模板结构化,可直接解析成底稿
- 自由文本 Notes(scope 漂移这类)机器读不了,原样收进「需人工阅读」节
- 网络失败时报错退出,不产出半截文件
"""
import re
import sys
import urllib.request
from pathlib import Path

UA = "SettingsHub-metadata-pipeline/1.0 (addon maintenance script)"


def fetch(version):
    # 页面是 Patch_X.Y.Z 的子页面,标题带斜杠(Patch_12.1.0/API_changes);下划线格式是 404
    url = f"https://warcraft.wiki.gg/index.php?title=Patch_{version}/API_changes&action=raw"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def parse(text):
    cvar_entries = []
    for m in re.finditer(r"\{\{apitooltip\|([^}]*)\}\}", text):
        params = {}
        for part in m.group(1).split("|"):
            if "=" in part:
                k, v = part.split("=", 1)
                params[k.strip()] = v.strip()
            elif part.strip():
                params.setdefault("name", part.strip())
        if params.get("t", params.get("type", "")).lower() == "cvar":
            cvar_entries.append(params)
    # cvar 相关的自由文本行(含 CVar 字样或已知家族前缀)也捞出来给人读
    notes = []
    for line in text.splitlines():
        low = line.lower()
        if "cvar" in low and not line.strip().startswith("{{apitooltip"):
            notes.append(line.strip())
    return cvar_entries, notes


def render(version, cvar_entries, notes):
    lines = [f"# Patch {version} CVar 变更底稿(wiki 抓取,策展用)", ""]
    lines.append(f"结构化条目 {len(cvar_entries)} 条,需人工阅读的自由文本 {len(notes)} 行。")
    lines.append("")
    lines.append(f"## apitooltip cvar 条目({len(cvar_entries)})")
    lines.append("")
    for e in cvar_entries:
        name = e.get("name", "?")
        extra = ", ".join(f"{k}={v}" for k, v in e.items() if k != "name")
        lines.append(f"- [ ] `{name}`" + (f"({extra})" if extra else ""))
    lines.append("")
    lines.append(f"## 需人工阅读的自由文本({len(notes)})")
    lines.append("")
    for n in notes:
        lines.append(f"- {n}")
    return "\n".join(lines) + "\n"


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    version = sys.argv[1]
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(f"dumps/wiki-{version}.md")
    text = fetch(version)
    cvar_entries, notes = parse(text)
    out.parent.mkdir(exist_ok=True)
    out.write_text(render(version, cvar_entries, notes), encoding="utf-8")
    print(f"{version}: 结构化 {len(cvar_entries)} 条 + 自由文本 {len(notes)} 行 -> {out}")


if __name__ == "__main__":
    main()
