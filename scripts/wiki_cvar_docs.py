#!/usr/bin/env python3
"""从 Warcraft Wiki 抓取并整理完整的 CVar 文档。"""
import json
import re
import urllib.request
from datetime import date
from pathlib import Path

API_URL = (
    "https://warcraft.wiki.gg/api.php?action=parse&"
    "page=Console_variables/Complete_list&prop=wikitext&format=json"
)
SOURCE_URL = "https://warcraft.wiki.gg/wiki/Console_variables/Complete_list"
UA = "SettingsHub-metadata-pipeline/1.0 (addon maintenance script)"
OUT = Path("dumps/wiki_cvar_docs.json")


def fetch():
    # wiki.gg 要求脚本请求明确标识 User-Agent,否则可能拒绝访问
    req = urllib.request.Request(API_URL, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["parse"]["wikitext"]["*"]


def clean_code(value):
    """去掉默认值外围的 code 标签,空单元格仍保留为空字符串。"""
    value = value.strip()
    match = re.fullmatch(r"<code>(.*?)</code>", value, re.DOTALL | re.IGNORECASE)
    return match.group(1).strip() if match else value


def parse(text):
    # 同一页面后半段还有 Console Commands 表,这里只解析前面的 CVar 表
    table = text.split("==List of Console Commands==", 1)[0]
    cvars = {}
    link_re = re.compile(r"\[\[CVar ([^|\]]+)(?:\|([^\]]+))?\]\]")

    for block in re.split(r"(?m)^\|-\s*$", table):
        lines = [
            line
            for line in block.splitlines()
            if line.startswith("|") and line.strip() != "|}"
        ]
        name_index = next((i for i, line in enumerate(lines) if link_re.search(line)), None)
        if name_index is None or name_index + 2 >= len(lines):
            continue

        name_line = lines[name_index]
        match = link_re.search(name_line)
        name = (match.group(2) or match.group(1)).strip()

        name_cells = name_line[1:].split("||")
        detail_cells = lines[name_index + 1][1:].split("||")
        if len(name_cells) < 4 or len(detail_cells) < 3:
            continue

        # 描述通常独占一行;合并后续行可兼容单元格内的意外换行
        desc_lines = lines[name_index + 2 :]
        desc = " ".join(line[1:].strip() for line in desc_lines).strip()
        cvars[name] = {
            "version": name_cells[0].strip(),
            "default": clean_code(detail_cells[0]),
            "category": detail_cells[1].strip(),
            "scope": detail_cells[2].strip(),
            "desc": desc,
        }

    return cvars


def main():
    cvars = parse(fetch())
    result = {
        "_meta": {
            "source": SOURCE_URL,
            "license": "CC BY-SA 4.0",
            "fetched": date.today().isoformat(),
        },
        "cvars": cvars,
    }
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    described = sum(len(item["desc"]) >= 10 for item in cvars.values())
    print(f"总条数: {len(cvars)}, desc 长度>=10: {described}")


if __name__ == "__main__":
    main()
