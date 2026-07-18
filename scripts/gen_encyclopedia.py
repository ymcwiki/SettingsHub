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
        fields = [
            f'zh = "{lua_string(zh[name])}"',
            f'en = "{lua_string(doc["desc"])}"',
        ]
        version = doc.get("version", "")
        if version:
            fields.append(f'ver = "{lua_string(version)}"')
        lines.append(f'\t["{lua_string(name)}"] = {{ {", ".join(fields)} }},')
    lines += ["}", ""]

    body = "\n".join(lines)
    size = len(body.encode("utf-8"))
    if size > BUDGET:
        sys.exit(f"Encyclopedia.lua {size} 字节,超出 {BUDGET} 字节预算")
    OUT.write_text(body, encoding="utf-8")
    print(f"{len(zh)} 条 -> {OUT.name}({size} 字节, {size / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
