-- P2 引擎无头测试。驱动:tests/run_headless.py(lupa lua51)
local ROOT = ROOT or "."
local stub = dofile(ROOT .. "/tests/wow_stub.lua")

local ADDON, ns = "SettingsHub", {}
local FILES = {
	"Core/Bootstrap.lua", "Core/Enum.lua", "Core/CombatQueue.lua", "Core/Blame.lua",
	"Adapters/Cvar.lua", "Core/Engine.lua", "Core/Replay.lua",
	"Data/Curated_A_Camera.lua", "Data/Curated_B_SoftTarget.lua", "Data/Curated_C_Nameplate.lua",
	"Data/Curated_D_CombatText.lua", "Data/Curated_E_QoL.lua", "Data/Curated_F_Graphics.lua",
	"Data/Curated_G_Sound.lua", "Data/Curated_H_Dev.lua", "Data/Exposed.lua",
	"UI/Search.lua",
	"SelfTest.lua",
}
-- 纯 UI 文件无法在桩里执行,只做编译级语法检查
local SYNTAX_ONLY = {
	"UI/MainFrame.lua", "UI/Browser.lua", "UI/LogPage.lua", "Integration/OfficialSettings.lua",
}
for _, f in ipairs(FILES) do
	local chunk = assert(loadfile(ROOT .. "/" .. f))
	chunk(ADDON, ns)
end

-- 种子:功能性条目 + 撑够枚举计数的哑元
stub.addCvar("cameraZoomSpeed", { value = "1", default = "1" })
stub.addCvar("rawMouseEnable", { value = "0", default = "0" })
stub.addCvar("nameplateMaxDistance", { value = "60", default = "60", secure = true })
stub.addCvar("lockedCvar", { value = "5", default = "5", readonly = true })
stub.addCvar("alwaysCompareItems", { value = "0", default = "0", sAcc = true })
stub.addCvar("autoLootDefault", { value = "0", default = "0", sChar = true })
stub.addCvar("reloadui", { commandType = 1 })
for i = 1, 1650 do stub.addCvar("dummyCvar" .. i, { value = "0", default = "0" }) end
local CVAR_TOTAL = 1656

local fails = 0
local function t(name, cond, detail)
	if cond then
		print("ok   " .. name)
	else
		fails = fails + 1
		print("FAIL " .. name .. (detail and ("  [" .. tostring(detail) .. "]") or ""))
	end
end

local E, Q = nil, nil

-- 启动
stub.fire("ADDON_LOADED", ADDON)
stub.fire("PLAYER_LOGIN")
E = ns.Engine
t("启动:db 初始化", ns.db ~= nil and ns.db.global.undoLog.head == 1)
local themeControls = 0
for _, th in ipairs(ns.Data.themes) do themeControls = themeControls + #th.controls end
t("数据种子:八主题已加载", #ns.Data.themes == 8 and themeControls > 0, themeControls)
t("枚举:计数正确且过滤掉 Command", ns.Enum.count == CVAR_TOTAL, ns.Enum.count)
t("枚举:Command 不在缓存", ns.Enum.cache["reloadui"] == nil)
t("枚举:secure 位正确", ns.Enum.cache["nameplateMaxDistance"].secure == true)
t("枚举:scope 判定", ns.Enum.cache["alwaysCompareItems"].scope == "account"
	and ns.Enum.cache["autoLootDefault"].scope == "character"
	and ns.Enum.cache["cameraZoomSpeed"].scope == "machine")

-- 基本写管线
local r = E:Set("cvar", "cameraZoomSpeed", "1.5", "user")
t("写入:applied", r == "applied")
t("写入:值生效", C_CVar.GetCVar("cameraZoomSpeed") == "1.5")
t("写入:baseline 首触记录", ns.db.global.baseline["cvar:cameraZoomSpeed"] == "1")
t("写入:期望态记录", ns.db.profile.cvar["cameraZoomSpeed"] == "1.5")
local e1 = E:LastEntry()
t("写入:日志字段", e1.key == "cameraZoomSpeed" and e1.old == "1" and e1.new == "1.5" and e1.source == "user")

E:Set("cvar", "cameraZoomSpeed", "2", "user")
t("二次写入:baseline 不变", ns.db.global.baseline["cvar:cameraZoomSpeed"] == "1")

-- 撤销
r = E:UndoLast()
t("撤销:applied 且值回退", r == "applied" and C_CVar.GetCVar("cameraZoomSpeed") == "1.5")
t("撤销:期望态回退", ns.db.profile.cvar["cameraZoomSpeed"] == "1.5")
r = E:UndoLast()
t("再撤销:回到初值", r == "applied" and C_CVar.GetCVar("cameraZoomSpeed") == "1")
t("再撤销:期望态清除", ns.db.profile.cvar["cameraZoomSpeed"] == nil)

-- 回默认
E:Set("cvar", "cameraZoomSpeed", "3", "user")
r = E:ResetToDefault("cvar", "cameraZoomSpeed")
t("回默认:值为 default", r == "applied" and C_CVar.GetCVar("cameraZoomSpeed") == "1")
t("回默认:期望态清除", ns.db.profile.cvar["cameraZoomSpeed"] == nil)

-- 失败路径
local before = ns.db.global.baseline["cvar:lockedCvar"]
r = E:Set("cvar", "lockedCvar", "9", "user")
t("只读写入:failed", r == "failed")
t("只读写入:失败清单", #E.failures == 1 and E.failures[1].key == "lockedCvar")
t("只读写入:日志条目标 failed", E:LastEntry().failed == true)
t("只读写入:baseline 未污染", ns.db.global.baseline["cvar:lockedCvar"] == nil and before == nil)
t("只读写入:期望态未记录", ns.db.profile.cvar["lockedCvar"] == nil)

-- 战斗队列
stub.state.inCombat = true
r = E:Set("cvar", "nameplateMaxDistance", "41", "user")
t("战斗中 secure:queued", r == "queued")
t("战斗中 secure:值未变", C_CVar.GetCVar("nameplateMaxDistance") == "60")
E:Set("cvar", "nameplateMaxDistance", "45", "user")
t("队列去重:仍只有一项", ns.CombatQueue:Size() == 1)
r = E:Set("cvar", "cameraZoomSpeed", "1.2", "user")
t("战斗中非 secure:直接 applied", r == "applied" and C_CVar.GetCVar("cameraZoomSpeed") == "1.2")
stub.state.inCombat = false
stub.fire("PLAYER_REGEN_ENABLED")
t("脱战 flush:后写覆盖生效", C_CVar.GetCVar("nameplateMaxDistance") == "45")
t("脱战 flush:队列清空", ns.CombatQueue:Size() == 0)

-- 环形日志回绕
for i = 1, 510 do
	E:Set("cvar", "rawMouseEnable", (i % 2 == 0) and "0" or "1", "user")
end
local slots = 0
for _ in pairs(ns.db.global.undoLog.entries) do slots = slots + 1 end
t("环形日志:槽位不超过 500", slots <= 500, slots)
r = E:UndoLast()
t("环形日志:回绕后仍可撤销", r == "applied")

-- 全量还原
local n, failedN = E:RestoreAll("uninstall")
t("全量还原:无失败", failedN == 0, failedN)
t("全量还原:值回首触原值", C_CVar.GetCVar("cameraZoomSpeed") == "1"
	and C_CVar.GetCVar("nameplateMaxDistance") == "60"
	and C_CVar.GetCVar("rawMouseEnable") == "0")
t("全量还原:baseline 清空", next(ns.db.global.baseline) == nil)
t("全量还原:期望态清空", next(ns.db.profile.cvar) == nil)

-- 重放断言
ns.db.profile.cvar["rawMouseEnable"] = "1"
stub.registry["rawMouseEnable"].value = "0" -- 模拟服务器后到同步覆盖,不走 SetCVar
ns.Replay:Assert()
t("重放断言:漂移被改回", C_CVar.GetCVar("rawMouseEnable") == "1")
ns.Replay:Assert()
local lastAfter = E:LastEntry()
ns.db.profile.cvar["rawMouseEnable"] = nil
E:Set("cvar", "rawMouseEnable", "0", "test")

-- blame
stub.state.stackAddon = "EvilAddon"
C_CVar.SetCVar("cameraZoomSpeed", "2.5")
t("blame:外部写入记录来源", ns.db.global.blame["cameraZoomSpeed"]
	and ns.db.global.blame["cameraZoomSpeed"].by == "EvilAddon")
stub.state.stackAddon = nil
E:Set("cvar", "cameraZoomSpeed", "1", "test")
t("blame:自写不覆盖", ns.db.global.blame["cameraZoomSpeed"].by == "EvilAddon")

-- 语法检查:UI 文件能编译
for _, f in ipairs(SYNTAX_ONLY) do
	local chunk, err = loadfile(ROOT .. "/" .. f)
	t("语法:" .. f, chunk ~= nil, err)
end

-- 搜索索引与过滤词
ns.Search:Rebuild()
t("搜索:索引条数", #ns.Search.items == CVAR_TOTAL, #ns.Search.items)
t("搜索:精确命中", #ns.Search:Query("camerazoomspeed") == 1)
t("搜索:多词 AND", #ns.Search:Query("camera zoom") == 1)
t("搜索:tag:secure", #ns.Search:Query("tag:secure") == 1)
E:Set("cvar", "dummyCvar7", "1", "user")
t("搜索:tag:modified", #ns.Search:Query("tag:modified") == 1
	and ns.Search:Query("tag:modified")[1].key == "dummyCvar7")
t("搜索:tag:hidden 未暴露项不受影响",
	#ns.Search:Query("dummycvar7 tag:hidden") == #ns.Search:Query("dummycvar7"))
E:Set("cvar", "dummyCvar7", "0", "test")
ns.db.profile.cvar["dummyCvar7"] = nil
t("搜索:类别计数", ns.Search:CategoryCounts()[4] == CVAR_TOTAL)

-- SelfTest 全流程(phase A 布置跨重登标记,phase B 验证)
local ok = ns.SelfTest:Run()
t("SelfTest phase A:全部断言通过", ok)
t("SelfTest phase A:标记已布置", ns.db.global.selftest ~= nil)
local markerKey = ns.db.global.selftest.key
local markerOld = ns.db.global.selftest.old
ok = ns.SelfTest:Run()
t("SelfTest phase B:全部断言通过", ok)
t("SelfTest phase B:标记清除且值复原", ns.db.global.selftest == nil
	and C_CVar.GetCVar(markerKey) == markerOld)

-- dump
ns.SelfTest:Dump()
t("dump:计数一致", ns.db.global.dump and ns.db.global.dump.count == CVAR_TOTAL)
t("dump:secure 位保留", ns.db.global.dump.cvars["nameplateMaxDistance"].s == 1)

print(string.format("== %s ==", fails == 0 and "ALL PASS" or (fails .. " FAILED")))
if fails > 0 then error(fails .. " test(s) failed", 0) end
