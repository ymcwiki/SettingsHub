#!/usr/bin/env python3
"""L1 元数据管线:解析游戏内 /sh dump 落盘的 SavedVariables,与上一版 dump 对比,产出 review 队列。

用法:
  python3 scripts/dump_diff.py <WTF/Account/<账号>/SavedVariables/SettingsHubDB.lua>
  python3 scripts/dump_diff.py --selftest    # 模拟一次补丁,验证 解析-diff-review 全流程

产物(均在 dumps/ 下,不进发布包):
  dump-<build>.json      本次全量
  review-<build>.md      review 队列:新增/删除/默认值变化/scope 漂移/secure 漂移
  latest.json            指向最新 dump(下次 diff 的基准)

review 队列处理完后,人工把结论回写 Data/Curated_*.lua 与 census JSON(流程见 docs/MAINTENANCE.md)。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DUMPS = ROOT / "dumps"


class LuaParser:
    """够用为止的 WoW SavedVariables 解析器:只处理 Blizzard 序列化器输出的子集。"""

    def __init__(self, text):
        self.s = text
        self.i = 0

    def error(self, msg):
        raise ValueError(f"SV 解析失败 @ {self.i}: {msg}: ...{self.s[self.i:self.i + 40]!r}")

    def ws(self):
        while self.i < len(self.s):
            c = self.s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif self.s.startswith("--", self.i):
                nl = self.s.find("\n", self.i)
                self.i = len(self.s) if nl < 0 else nl + 1
            else:
                break

    def expect(self, ch):
        self.ws()
        if not self.s.startswith(ch, self.i):
            self.error(f"期望 {ch!r}")
        self.i += len(ch)

    def parse_string(self):
        assert self.s[self.i] == '"'
        self.i += 1
        out = []
        while True:
            c = self.s[self.i]
            if c == "\\":
                nxt = self.s[self.i + 1]
                out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\", "r": "\r"}.get(nxt, nxt))
                self.i += 2
            elif c == '"':
                self.i += 1
                return "".join(out)
            else:
                out.append(c)
                self.i += 1

    def parse_value(self):
        self.ws()
        c = self.s[self.i]
        if c == "{":
            return self.parse_table()
        if c == '"':
            return self.parse_string()
        for lit, val in (("true", True), ("false", False), ("nil", None)):
            if self.s.startswith(lit, self.i):
                self.i += len(lit)
                return val
        j = self.i
        while self.s[j] in "-+.0123456789eE":
            j += 1
        if j == self.i:
            self.error("非法值")
        num = self.s[self.i:j]
        self.i = j
        return float(num) if any(x in num for x in ".eE") else int(num)

    def parse_table(self):
        self.expect("{")
        out, arr_i = {}, 1
        while True:
            self.ws()
            if self.s.startswith("}", self.i):
                self.i += 1
                return out
            if self.s.startswith("[", self.i):
                self.i += 1
                key = self.parse_value()
                self.expect("]")
                self.expect("=")
                out[key] = self.parse_value()
            else:
                out[arr_i] = self.parse_value()
                arr_i += 1
            self.ws()
            if self.s.startswith(",", self.i) or self.s.startswith(";", self.i):
                self.i += 1


def parse_sv(text):
    eq = text.find("=")
    parser = LuaParser(text[eq + 1:])
    return parser.parse_value()


def scope_of(entry):
    if entry.get("a"):
        return "account"
    if entry.get("c"):
        return "character"
    return "machine"


def diff(old_cvars, new_cvars):
    added = sorted(set(new_cvars) - set(old_cvars))
    removed = sorted(set(old_cvars) - set(new_cvars))
    default_changed, scope_drift, secure_drift = [], [], []
    for name in sorted(set(old_cvars) & set(new_cvars)):
        o, n = old_cvars[name], new_cvars[name]
        if o.get("d") != n.get("d"):
            default_changed.append((name, o.get("d"), n.get("d")))
        if scope_of(o) != scope_of(n):
            scope_drift.append((name, scope_of(o), scope_of(n)))
        if bool(o.get("s")) != bool(n.get("s")):
            secure_drift.append((name, bool(o.get("s")), bool(n.get("s"))))
    return added, removed, default_changed, scope_drift, secure_drift


def render_review(build, old_build, d):
    added, removed, default_changed, scope_drift, secure_drift = d
    lines = [f"# CVar review 队列:{old_build} 到 {build}", ""]
    lines.append(f"新增 {len(added)} / 删除 {len(removed)} / 默认值变化 {len(default_changed)}"
                 f" / scope 漂移 {len(scope_drift)} / secure 漂移 {len(secure_drift)}")
    lines.append("")
    lines.append("处理约定:每条勾掉前先决定三件事:进不进策展(Data/)、census JSON 要不要回写、")
    lines.append("要不要在条目 version 里加「X.Y 起变更」注记。")

    def section(title, rows, fmt):
        lines.append("")
        lines.append(f"## {title}({len(rows)})")
        lines.append("")
        for r in rows:
            lines.append("- [ ] " + fmt(r))

    section("新增", added, lambda n: f"`{n}`")
    section("删除(检查策展数据与 profile 引用)", removed, lambda n: f"`{n}`")
    section("默认值变化", default_changed, lambda r: f"`{r[0]}`:{r[1]!r} 变 {r[2]!r}")
    section("scope 漂移(影响重放判定与徽章)", scope_drift, lambda r: f"`{r[0]}`:{r[1]} 变 {r[2]}")
    section("secure 漂移(影响战斗锁定)", secure_drift, lambda r: f"`{r[0]}`:{r[1]} 变 {r[2]}")
    return "\n".join(lines) + "\n"


def run(sv_path):
    data = parse_sv(Path(sv_path).read_text(encoding="utf-8"))
    dump = data.get("global", {}).get("dump")
    if not dump:
        sys.exit("SV 里没有 global.dump,先在游戏内跑 /sh dump 再退出游戏")
    build = str(dump.get("build", "unknown"))
    cvars = dump.get("cvars", {})
    DUMPS.mkdir(exist_ok=True)

    latest_path = DUMPS / "latest.json"
    if latest_path.exists():
        old = json.loads(latest_path.read_text())
        d = diff(old["cvars"], cvars)
        review = render_review(build, old.get("build", "?"), d)
        review_path = DUMPS / f"review-{build}.md"
        review_path.write_text(review, encoding="utf-8")
        print(f"review 队列 -> {review_path}")
        print(review.splitlines()[2])
    else:
        print("无历史 dump,本次仅入库作基准")

    payload = {"build": build, "version": dump.get("version"), "count": dump.get("count"), "cvars": cvars}
    (DUMPS / f"dump-{build}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    latest_path.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"dump 已入库 -> dumps/dump-{build}.json(latest 已更新)")


def selftest():
    sv = '''SettingsHubDB = {
	["global"] = {
		["dump"] = {
			["build"] = "58100",
			["version"] = "12.1.5",
			["count"] = 4,
			["cvars"] = {
				["keptSame"] = { ["d"] = "1", ["h"] = "unchanged", },
				["defaultFlip"] = { ["d"] = "0", },
				["scopeMove"] = { ["d"] = "5", ["c"] = 1, },
				["brandNew"] = { ["d"] = "todo", ["s"] = 1, },
			},
		},
	},
}'''
    old = {
        "build": "58000",
        "cvars": {
            "keptSame": {"d": "1"},
            "defaultFlip": {"d": "1"},
            "scopeMove": {"d": "5", "a": 1},
            "goneSoon": {"d": "x"},
        },
    }
    data = parse_sv(sv)
    cvars = data["global"]["dump"]["cvars"]
    d = diff(old["cvars"], cvars)
    added, removed, default_changed, scope_drift, secure_drift = d
    assert added == ["brandNew"], added
    assert removed == ["goneSoon"], removed
    assert default_changed == [("defaultFlip", "1", "0")], default_changed
    assert scope_drift == [("scopeMove", "account", "character")], scope_drift
    assert secure_drift == [], secure_drift
    review = render_review("58100", "58000", d)
    assert "`brandNew`" in review and "defaultFlip" in review and "scope 漂移(影响重放判定与徽章)(1)" in review
    print("SELFTEST PASS:解析、diff、review 渲染全流程正常")
    print(review)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if sys.argv[1] == "--selftest":
        selftest()
    else:
        run(sys.argv[1])
