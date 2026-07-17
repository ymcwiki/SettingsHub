#!/usr/bin/env python3
"""从 cvar-census/hidden_cvars.json 生成 Data/Curated_*.lua 控件定义骨架。

选择规则来自调研报告第六章的八大主题;text.zh/text.en/keywords 留空由人工策展填写
(v0.2 schema:zh/en 是两种语言的白话说明,keywords 是搜索关键词数组)。
运行时 default/scope/secure 以实机 GetCVarInfo 为准,这里只是种子。

用法: python3 scripts/census2lua.py [census_json_path]
"""
import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CENSUS = Path.home() / "Dropbox/Addons/项目-设置插件/cvar-census/hidden_cvars.json"

# (letter, slug, id 前缀, 标题, [正则,不区分大小写,全名匹配])
THEMES = [
    ("A", "Camera", "camera", "相机与 ActionCam",
     [r"test_camera.*", r"cameraDistanceMaxZoomFactor", r"cameraZoomSpeed", r".*fov.*"]),
    ("B", "SoftTarget", "target", "软目标与目标选取",
     [r"SoftTarget.*", r"TargetNearest.*"]),
    ("C", "Nameplate", "nameplate", "姓名板",
     [r"nameplate.*", r"NamePlate.*"]),
    ("D", "CombatText", "combattext", "战斗浮动文字",
     [r"floatingCombatText.*", r"WorldText.*"]),
    ("E", "QoL", "qol", "界面与 QoL 杂项",
     [r"rawMouseEnable", r"SpellQueueWindow", r"alwaysCompareItems", r"autoLootRate",
      r"breakUpLargeNumbers", r"violenceLevel", r"uiScaleMultiplier", r"discordClientEnabled",
      r"threat.*", r".*[Tt]ransmog.*"]),
    ("F", "Graphics", "graphics", "图形性能与画质",
     [r"ffx.*", r"weatherDensity", r"farclip", r"DynamicRenderScale.*", r".*[Ss]creenshot.*",
      r"RAID.*"]),
    ("G", "Sound", "sound", "声音",
     [r".*ArmorFoley.*", r".*[Ff]ootstep.*", r".*EmoteSounds.*", r".*OutputDriver.*",
      r".*SampleRate.*", r".*DSP.*", r".*[Ll]istener.*"]),
    ("H", "Dev", "dev", "开发者",
     [r"scriptErrors", r"taintLog.*", r"scriptProfile", r"addon.*RestrictionsForced",
      r"addonLoadDebugging", r"fstack_.*"]),
]


def guess_type(default, help_text):
    if default in ("0", "1") and (not help_text or re.search(r"[01]\s*[:=]|[Ee]nable|[Dd]isable", help_text)):
        return "bool"
    if default is not None:
        try:
            float(default)
            return "number"
        except ValueError:
            pass
    return "string"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    census_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CENSUS
    census = json.loads(census_path.read_text())

    assigned = {}
    for name in sorted(census):
        for letter, slug, prefix, title, patterns in THEMES:
            if any(re.fullmatch(p, name, re.IGNORECASE) for p in patterns):
                assigned.setdefault(letter, []).append(name)
                break

    total = 0
    for letter, slug, prefix, title, _ in THEMES:
        names = assigned.get(letter, [])
        total += len(names)
        out = ROOT / "Data" / f"Curated_{letter}_{slug}.lua"
        if out.exists() and "人工策展定版" in out.read_text():
            print(f"{letter} {title}: 跳过,{out.name} 是 P4 人工定版(要重建先手动删除)")
            continue
        lines = [
            f"-- 由 scripts/census2lua.py 生成于 {date.today().isoformat()},来源 cvar-census 12.1.0 差集",
            "-- text.zh 为空的条目在 P4 阶段人工填写;运行时 default/scope/secure 以实机 GetCVarInfo 为准",
            "local ADDON, ns = ...",
            "",
            "ns.Data = ns.Data or {}",
            "ns.Data.themes = ns.Data.themes or {}",
            "",
            "ns.Data.themes[#ns.Data.themes + 1] = {",
            f'\tkey = "{letter}", title = "{title}",',
            "\tcontrols = {",
        ]
        for name in names:
            e = census[name]
            default = e.get("default")
            help_text = e.get("help") or ""
            ctype = guess_type(default, help_text)
            scope = e.get("scope")
            fields = [
                f'id = "{prefix}.{name}"',
                'domain = "cvar"',
                f'key = "{name}"',
                f'type = "{ctype}"',
            ]
            if default is not None:
                fields.append(f"default = {lua_str(default)}")
            if scope:
                fields.append(f'seedScope = "{scope.lower()}"')
            if e.get("secure"):
                fields.append("secure = true")
            lines.append("\t\t{ " + ", ".join(fields) + ",")
            lines.append('\t\t  text = { zh = "", en = "", keywords = {} },'
                         + (f" help = {lua_str(help_text)}," if help_text else ""))
            lines.append("\t\t},")
        lines += ["\t},", "}", ""]
        out = ROOT / "Data" / f"Curated_{letter}_{slug}.lua"
        out.parent.mkdir(exist_ok=True)
        out.write_text("\n".join(lines))
        print(f"{letter} {title}: {len(names)} 条 -> {out.name}")

    print(f"共 {total} 条(差集全量 {len(census)},未选入 {len(census) - total} 条)")

    exposed_path = census_path.parent / "exposed_cvars.json"
    if exposed_path.exists():
        exposed = json.loads(exposed_path.read_text())
        names = sorted(exposed)
        lines = [
            f"-- 由 scripts/census2lua.py 生成于 {date.today().isoformat()}:官方设置 UI 触及的 CVar 集(tag:hidden 取反用)",
            "local ADDON, ns = ...",
            "",
            "ns.Data = ns.Data or {}",
            "ns.Data.exposed = {",
        ]
        for n in names:
            lines.append(f"\t[{lua_str(n)}] = true,")
        lines += ["}", ""]
        (ROOT / "Data" / "Exposed.lua").write_text("\n".join(lines))
        print(f"exposed: {len(names)} 条 -> Exposed.lua")


if __name__ == "__main__":
    main()
