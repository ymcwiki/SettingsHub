-- P2 引擎无头测试。驱动:tests/run_headless.py(lupa lua51)
local ROOT = ROOT or "."
local stub = dofile(ROOT .. "/tests/wow_stub.lua")

local ADDON, ns = "SettingsHub", {}
local FILES = {
	"Core/Bootstrap.lua", "Core/Enum.lua", "Core/CombatQueue.lua", "Core/Blame.lua",
	"Adapters/Cvar.lua", "Adapters/Binding.lua", "Adapters/Macro.lua", "Adapters/EditMode.lua",
	"Adapters/ClickBinding.lua", "Adapters/MuteSound.lua", "Adapters/TTS.lua", "Adapters/ConsoleExec.lua",
	"Core/Engine.lua", "Core/Replay.lua", "Core/Actions.lua", "Core/Profiles.lua",
	"Data/Curated_A_Camera.lua", "Data/Curated_B_SoftTarget.lua", "Data/Curated_C_Nameplate.lua",
	"Data/Curated_D_CombatText.lua", "Data/Curated_E_QoL.lua", "Data/Curated_F_Graphics.lua",
	"Data/Curated_G_Sound.lua", "Data/Curated_H_Dev.lua", "Data/Exposed.lua",
	"UI/Search.lua",
	"SelfTest.lua",
}
-- 纯 UI 文件无法在桩里执行,只做编译级语法检查
local SYNTAX_ONLY = {
	"UI/MainFrame.lua", "UI/Browser.lua", "UI/Widgets.lua", "UI/ThemePage.lua",
	"UI/ProfilePage.lua", "UI/LogPage.lua", "Integration/OfficialSettings.lua",
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
-- 策展数据完整性:字段齐全、id/key 唯一、officialSearch 全为 bool 且数量达标
do
	local total, officialBools, badField, dupe = 0, 0, nil, nil
	local seenIds, seenKeys = {}, {}
	local function walk(controls)
		for _, c in ipairs(controls) do
			total = total + 1
			if not c.id or not c.type or not (c.text and c.text.zh and c.text.zh ~= "") then
				badField = c.id or c.key or "?"
			end
			if c.domain and not c.key then badField = c.id end
			if c.type == "enum" and not c.values then badField = c.id end
			if c.type == "action" and not c.run then badField = c.id end
			if seenIds[c.id] then dupe = c.id end
			seenIds[c.id] = true
			if c.domain == "cvar" then
				if seenKeys[c.key] then dupe = c.key end
				seenKeys[c.key] = true
			end
			if c.officialSearch then
				officialBools = officialBools + 1
				if c.type ~= "bool" then badField = c.id .. ":officialSearch非bool" end
			end
			if c.children then walk(c.children) end
		end
	end
	for _, th in ipairs(ns.Data.themes) do walk(th.controls) end
	t("策展数据:八主题", #ns.Data.themes == 8)
	t("策展数据:字段完整", badField == nil, badField)
	t("策展数据:id/key 唯一", dupe == nil, dupe)
	t("策展数据:officialSearch bool >= 20", officialBools >= 20, officialBools)
	t("策展数据:总条数 >= 85", total >= 85, total)
end
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

-- P5 非 CVar 域适配器
r = E:Set("consoleexec", "actioncam", "full", "user")
t("consoleexec:applied 且期望态记录", r == "applied" and ns.db.profile.consoleexec.actioncam == "full")
t("consoleexec:命令已执行", stub.consoleLog[#stub.consoleLog] == "actioncam full")
local ceLogs = #stub.consoleLog
ns.Adapters.consoleexec:ReplayAll()
t("consoleexec:登录重放执行", #stub.consoleLog == ceLogs + 1)

E:Set("mutesound", "569593", "1", "user")
t("mutesound:静音生效且入列表", stub.muted[569593] == true and #ns.db.profile.mutesound == 1)
t("mutesound:Read 回读", ns.Adapters.mutesound:Read("569593") == "1")
local msnap0 = ns.Adapters.mutesound:Serialize()
E:Set("mutesound", "569593", "0", "user")
t("mutesound:移除", stub.muted[569593] == nil and #ns.db.profile.mutesound == 0)
ns.Adapters.mutesound:Restore(msnap0)
t("mutesound:导入回环", stub.muted[569593] == true and #ns.db.profile.mutesound == 1)
E:Set("mutesound", "569593", "0", "test")

local bsnap = ns.Adapters.binding:Serialize()
t("binding:导出含键位与 ModifiedClick", bsnap.bindings.JUMP and bsnap.bindings.JUMP[1] == "SPACE"
	and bsnap.modified.SELFCAST == "ALT")
stub.keyToCmd.SPACE = nil
stub.modifiedClicks.SELFCAST = "NONE"
local sbCalls = stub.saveBindingsCalls
ns.Adapters.binding:Restore(bsnap)
t("binding:导入回环且统一 SaveBindings", stub.keyToCmd.SPACE == "JUMP"
	and stub.modifiedClicks.SELFCAST == "ALT" and stub.saveBindingsCalls == sbCalls + 1)

local cbsnap = ns.Adapters.clickbinding:Serialize()
t("clickbinding:宏条目按名导出", cbsnap[2].macroName == "TestMacro")

local mcsnap = ns.Adapters.macro:Serialize()
t("macro:导出账号+角色", #mcsnap.account == 1 and mcsnap.account[1].name == "AccMacro"
	and #mcsnap.character == 1)
DeleteMacro(121)
CreateMacro("Filler", "icon", "/sit", true)
ns.Adapters.macro:Restore(mcsnap)
t("macro:按名重建且检测漂移", GetMacroIndexByName("TestMacro") == 122)

ns.Adapters.clickbinding:Restore(cbsnap)
t("clickbinding:导入按宏名重映射", stub.clickProfile[2].actionID == 122
	and stub.clickProfile[1].actionID == 133)

local esnap = ns.Adapters.editmode:Serialize()
t("editmode:导出用户布局(跳过预设)", #esnap.layouts == 1 and esnap.layouts[1].name == "MyLayout"
	and esnap.layouts[1].str == "EMS:blob1")
stub.editMode.layouts[2].data = "corrupted"
stub.editMode.activeLayout = 1
ns.Adapters.editmode:Restore(esnap)
t("editmode:导入回环含激活布局", stub.editMode.layouts[2].data == "blob1"
	and stub.editMode.activeLayout == 2)

local tsnap = ns.Adapters.tts:Serialize()
stub.tts.rate = 5
stub.tts.bools[0] = false
ns.Adapters.tts:Restore(tsnap)
t("tts:导入回环", stub.tts.rate == 0 and stub.tts.bools[0] == true)

-- 战斗中批量域拒绝写入
stub.state.inCombat = true
local okB = ns.Adapters.binding:Restore(bsnap)
local okM = ns.Adapters.macro:Restore(mcsnap)
t("战斗锁:binding/macro Restore 拒绝", okB == false and okM == false)
stub.state.inCombat = false

-- P6 profile:导出导入(真 LibSerialize/LibDeflate 管线)
E:Set("cvar", "dummyCvar9", "1", "user")
ns.Profiles:CaptureDomain("tts")
local exported = ns.Profiles:Export()
t("profile:导出串带魔法头", exported:sub(1, 5) == "!SH1!")
local payload, perr = ns.Profiles:Decode(exported)
t("profile:解码回环", payload ~= nil and payload.data.cvar.dummyCvar9 == "1"
	and payload.data.tts ~= nil, perr)
t("profile:坏串有错误信息", (select(2, ns.Profiles:Decode("garbage"))) ~= nil)
E:Set("cvar", "dummyCvar9", "0", "test")
stub.tts.rate = 9
local changes, bulkList = ns.Profiles:DiffAgainstCurrent(payload)
t("profile:diff 检出改动与整域", #changes >= 1 and #bulkList >= 1)
ns.Profiles:ApplyImport(payload)
t("profile:导入应用一致", C_CVar.GetCVar("dummyCvar9") == "1" and stub.tts.rate == 0)
E:Set("cvar", "dummyCvar9", "0", "test")
ns.db.profile.cvar.dummyCvar9 = nil
ns.db.profile.domains.tts = nil

-- P6 四轴:场景轴切换与回落
ns.db.global.autoSwitch.scene.enabled = true
ns.db.global.autoSwitch.scene.map.raid = "RaidProfile"
ns.db.global.autoSwitch.onLeave = "restore"
ns.Profiles:Switch("RaidProfile", "预置")
E:Set("cvar", "dummyCvar11", "1", "user")
ns.Profiles:Switch("Default", "回基准")
t("profile:手动切换更新角色基准", ns.db.char.baseProfile == "Default")
E:Set("cvar", "dummyCvar11", "0", "test")
stub.state.instanceType = "raid"
stub.fire("PLAYER_ENTERING_WORLD")
t("四轴:进团本自动切换", ns.Profiles:Current() == "RaidProfile")
t("四轴:目标 profile 期望态已应用", C_CVar.GetCVar("dummyCvar11") == "1")
stub.state.instanceType = "none"
stub.fire("PLAYER_ENTERING_WORLD")
t("四轴:离开场景自动回落基准", ns.Profiles:Current() == "Default")

-- P6 四轴:专精轴 + 关轴回落
ns.db.global.autoSwitch.spec.enabled = true
ns.db.global.autoSwitch.spec.map[251] = "RaidProfile"
stub.state.spec = 1
stub.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
t("四轴:专精轴切换", ns.Profiles:Current() == "RaidProfile")
ns.db.global.autoSwitch.spec.enabled = false
stub.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
t("四轴:关轴后回落", ns.Profiles:Current() == "Default")
ns.db.global.autoSwitch.scene.enabled = false

-- P6 整域快照撤销
local bulkEntry
do
	local log = ns.db.global.undoLog
	for i = 0, 499 do
		local p = ((log.head - 2 - i) % 500) + 1
		local e = log.entries[p]
		if not e then break end
		if e.bulk and e.domain == "cvar" and not e.undone then bulkEntry = e break end
	end
end
t("四轴:切换留下整域快照", bulkEntry ~= nil and bulkEntry.old.dummyCvar11 == "1")
E:Set("cvar", "dummyCvar11", "0", "test")
r = E:Undo(bulkEntry)
t("四轴:整域快照可撤销", r == "applied" and C_CVar.GetCVar("dummyCvar11") == "1")
ns.db.profile.cvar.dummyCvar11 = nil
E:Set("cvar", "dummyCvar11", "0", "test")

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
