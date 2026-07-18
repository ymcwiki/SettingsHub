#!/usr/bin/env python3
"""合并 wiki CVar 文档与中文词典,生成 Data/Encyclopedia.lua。

用法: python3 scripts/gen_encyclopedia.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIKI = ROOT / "dumps" / "wiki_cvar_docs.json"
ZH = ROOT / "scripts" / "data" / "dictionary_zh.json"
SUPPLEMENTS_EN = ROOT / "scripts" / "data" / "supplements_en.json"
FAMILY = ROOT / "scripts" / "data" / "family.json"
OUT = ROOT / "Data" / "Encyclopedia.lua"
BUDGET = 400 * 1024


def lua_string(value):
    """把值转成可安全放进 Lua 双引号字符串的内容。"""
    return (
        str(value)
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def main():
    wiki = json.loads(WIKI.read_text(encoding="utf-8"))["cvars"]
    zh = json.loads(ZH.read_text(encoding="utf-8"))["zh"]
    supplements_en = json.loads(SUPPLEMENTS_EN.read_text(encoding="utf-8"))
    family = json.loads(FAMILY.read_text(encoding="utf-8"))["entries"]

    lines = [
        "-- 由 scripts/gen_encyclopedia.py 生成,勿手改",
        "-- 数据来源: warcraft.wiki.gg (CC BY-SA 4.0)",
        "-- 重新生成: python3 scripts/gen_encyclopedia.py",
        "local ADDON, ns = ...",
        "",
        "ns.Data = ns.Data or {}",
        "ns.Data.encyclopedia = {",
    ]
    for name in sorted(zh):
        doc = wiki[name]
        en = doc.get("desc", "") or supplements_en[name]
        fields = [
            f'zh = "{lua_string(zh[name])}"',
            f'en = "{lua_string(en)}"',
        ]
        version = doc.get("version", "")
        if version:
            fields.append(f'ver = "{lua_string(version)}"')
        lines.append(f'\t["{lua_string(name)}"] = {{ {", ".join(fields)} }},')

    family_only = set(family) - set(zh)
    for name in sorted(family_only):
        entry = family[name]
        fields = [
            f'zh = "{lua_string(entry["zh"])}"',
            f'en = "{lua_string(entry["en"])}"',
            'src = "f"',
        ]
        version = wiki.get(name, {}).get("version", "")
        if version:
            fields.append(f'ver = "{lua_string(version)}"')
        lines.append(f'\t["{lua_string(name)}"] = {{ {", ".join(fields)} }},')
    lines += ["}", ""]

    body = "\n".join(lines)
    size = len(body.encode("utf-8"))
    if size > BUDGET:
        sys.exit(f"Encyclopedia.lua {size} 字节,超出 {BUDGET} 字节预算")
    OUT.write_text(body, encoding="utf-8")
    print(
        f"词典层 {len(zh)} 条 + 族群层 {len(family_only)} 条 = {len(zh) + len(family_only)} 条"
        f" -> {OUT.name}({size} 字节, {size / 1024:.1f} KB)"
    )


if __name__ == "__main__":
    main()
