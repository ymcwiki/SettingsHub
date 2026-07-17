#!/usr/bin/env python3
"""从 Data/Curated_*.lua 与 Data/Packs.lua 的中文文案提取用字,生成 Data/Pinyin.lua(字到拼音映射)。

搜索索引用它把策展 zh 文案转成全拼加首字母串(UI/Search.lua),体积预算 100KB(超限报错)。
策展文案改动后重跑本脚本;多音字取 pypinyin 默认最常用读音,搜索场景够用。

用法: python3 scripts/gen_pinyin.py   (需 .venv 里有 pypinyin)
"""
import re
import sys
from datetime import date
from pathlib import Path

from pypinyin import lazy_pinyin

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "Pinyin.lua"
BUDGET = 100 * 1024

CJK = re.compile(r"[一-鿿]")


def main():
    chars = set()
    for path in sorted(ROOT.glob("Data/Curated_*.lua")) + [ROOT / "Data" / "Packs.lua"]:
        chars.update(CJK.findall(path.read_text(encoding="utf-8")))

    mapping = {}
    for ch in sorted(chars):
        py = lazy_pinyin(ch)[0]
        if py and py != ch:
            mapping[ch] = py

    lines = [
        f"-- 由 scripts/gen_pinyin.py 生成于 {date.today().isoformat()},勿手改;策展文案改动后重跑脚本",
        "local ADDON, ns = ...",
        "",
        "ns.Data = ns.Data or {}",
        "ns.Data.pinyin = {",
    ]
    for ch, py in mapping.items():
        lines.append(f'\t["{ch}"] = "{py}",')
    lines += ["}", ""]
    body = "\n".join(lines)
    if len(body.encode()) > BUDGET:
        sys.exit(f"Pinyin.lua {len(body.encode())} 字节,超出 {BUDGET} 预算")
    OUT.write_text(body, encoding="utf-8")
    print(f"{len(mapping)} 字 -> {OUT.name}({len(body.encode()) // 1024} KB)")


if __name__ == "__main__":
    main()
