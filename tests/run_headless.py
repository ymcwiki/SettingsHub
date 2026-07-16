#!/usr/bin/env python3
"""无头测试驱动:用 lupa 的 Lua 5.1(与 WoW 同版本)跑 tests/run.lua。"""
import sys
from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent

lr = lua51.LuaRuntime()
lr.globals().ROOT = str(ROOT)
try:
    lr.execute((ROOT / "tests" / "run.lua").read_text())
except Exception as e:
    print(f"HEADLESS FAILED: {e}")
    sys.exit(1)
print("HEADLESS OK")
