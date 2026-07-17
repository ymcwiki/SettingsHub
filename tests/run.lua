-- P2 引擎无头测试。驱动:tests/run_headless.py(lupa lua51)
local ROOT = ROOT or "."
local stub = dofile(ROOT .. "/tests/wow_stub.lua")

local ADDON, ns = "SettingsHub", {}
local FILES = {
	"Locales/Locale.lua", "Locales/zhCN.lua",
	"Core/Bootstrap.lua", "Core/Enum.lua", "Core/CombatQueue.lua", "Core/Blame.lua",
	"Adapters/Cvar.lua", "Adapters/Binding.lua", "Adapters/Macro.lua", "Adapters/EditMode.lua",
	"Adapters/ClickBinding.lua", "Adapters/MuteSound.lua", "Adapters/TTS.lua", "Adapters/ConsoleExec.lua",
	"Adapters/ChatWindow.lua",
	"Core/Engine.lua", "Core/Conflicts.lua", "Core/Replay.lua", "Core/Actions.lua", "Core/Profiles.lua",
	"Core/Snapshots.lua", "Core/Packs.lua",
	"Data/Curated_A_Camera.lua", "Data/Curated_B_SoftTarget.lua", "Data/Curated_C_Nameplate.lua",
	"Data/Curated_D_CombatText.lua", "Data/Curated_E_QoL.lua", "Data/Curated_F_Graphics.lua",
	"Data/Curated_G_Sound.lua", "Data/Curated_H_Dev.lua", "Data/Curated_I_Chat.lua",
	"Data/Curated_J_Input.lua", "Data/Curated_K_QuestMap.lua",
	"Data/Packs.lua", "Data/Pinyin.lua", "Data/Exposed.lua",
	"UI/Search.lua",
	"SelfTest.lua",
}
-- 纯 UI 文件无法在桩里执行,只做编译级语法检查
local SYNTAX_ONLY = {
	"UI/MainFrame.lua", "UI/Browser.lua", "UI/Widgets.lua", "UI/ThemePage.lua", "UI/PackPage.lua",
	"UI/ProfilePage.lua", "UI/SnapshotPage.lua", "UI/LogPage.lua", "Integration/OfficialSettings.lua",
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
-- v0.3 推荐包引用的策展键(应用测试要真实写入)
for _, name in ipairs({
	"AdvFlyingDynamicFOVEnabled", "DriveDynamicFOVEnabled", "test_cameraDynamicPitch",
	"test_cameraHeadMovementStrength", "ffxNether", "RAIDweatherDensity", "RAIDshadowMode",
	"RAIDparticleDensity", "RAIDfarclip", "nameplateShowEnemyPets", "nameplateShowEnemyTotems",
	"nameplateShowEnemyGuardians", "cameraDistanceMaxZoomFactor", "threatShowNumeric",
	"breakUpLargeNumbers", "missingTransmogSourceInItemTooltips",
}) do
	stub.addCvar(name, { value = "0", default = "0" })
end
for i = 1, 1650 do stub.addCvar("dummyCvar" .. i, { value = "0", default = "0" }) end
local CVAR_TOTAL = 0
for _, e in pairs(stub.registry) do
	if e.commandType == 0 then CVAR_TOTAL = CVAR_TOTAL + 1 end
end

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
-- 策展数据完整性:zh/en/keywords 三字段齐全、id/key 唯一、officialSearch 全为 bool 且数量达标
do
	local total, officialBools, badField, dupe = 0, 0, nil, nil
	local seenIds, seenKeys = {}, {}
	local function walk(controls)
		for _, c in ipairs(controls) do
			total = total + 1
			if not c.id or not c.type
				or not (c.text and c.text.zh and c.text.zh ~= "")
				or type(c.text.en) ~= "string" or c.text.en == ""
				or type(c.text.keywords) ~= "table" or #c.text.keywords == 0 then
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
	t("策展数据:十一主题", #ns.Data.themes == 11, #ns.Data.themes)
	t("策展数据:zh/en/keywords 字段完整", badField == nil, badField)
	t("策展数据:id/key 唯一", dupe == nil, dupe)
	t("策展数据:officialSearch bool >= 25", officialBools >= 25, officialBools)
	t("策展数据:总条数 >= 120", total >= 120, total)
end

-- T1 本地化:zhCN 表命中、未知键回落、策展文案按语言取值、行标签第一句切分
do
	t("本地化:已知键取译文", ns.L["Undo"] == "撤销" and ns.L["Browser"] == "浏览器")
	t("本地化:未知键回落原文", ns.L["__no_such_key__"] == "__no_such_key__")
	local zoom
	for _, th in ipairs(ns.Data.themes) do
		for _, c in ipairs(th.controls) do
			if c.key == "cameraZoomSpeed" then zoom = c end
		end
	end
	t("本地化:zhCN 下 ControlText 取中文", ns.ControlText(zoom):find("滚轮", 1, true) == 1)
	t("本地化:ControlLabel 取第一句", ns.ControlLabel(zoom) == "滚轮缩放速度")
end

-- T1 本地化:zhCN 表覆盖完整性(源码 L 键 + 数据文件动态键,缺译即挂)
do
	local missing
	local function need(key, where)
		if rawget(ns.L, key) == nil and not missing then
			missing = where .. ": " .. key
		end
	end
	local scan = {}
	for _, f in ipairs(FILES) do scan[#scan + 1] = f end
	for _, f in ipairs(SYNTAX_ONLY) do scan[#scan + 1] = f end
	for _, f in ipairs(scan) do
		if f ~= "Locales/zhCN.lua" then
			local fh = assert(io.open(ROOT .. "/" .. f, "r"))
			local src = fh:read("*a")
			fh:close()
			for key in src:gmatch('L%["([^"]+)"%]') do need(key, f) end
		end
	end
	local function walkKeys(controls)
		for _, c in ipairs(controls) do
			if c.buttonText then need(c.buttonText, c.id) end
			for _, label in pairs(c.valueLabels or {}) do need(label, c.id) end
			if c.children then walkKeys(c.children) end
		end
	end
	for _, th in ipairs(ns.Data.themes) do
		need(th.title, "theme " .. th.key)
		walkKeys(th.controls)
	end
	t("本地化:zhCN 覆盖全部键", missing == nil, missing)
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
t("搜索:多词 AND", #ns.Search:Query("camera zoom speed") == 1, #ns.Search:Query("camera zoom speed"))
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

-- 12.0.7 兼容:AreCVarsLoaded 不存在时枚举照常;存在且返回 false 时才拒绝
do
	local saved = C_CVar.AreCVarsLoaded
	C_CVar.AreCVarsLoaded = nil
	local ok2, n2 = ns.Enum:Refresh()
	t("枚举:无 AreCVarsLoaded API(12.0.7)照常枚举", ok2 == true and n2 == CVAR_TOTAL, tostring(n2))
	C_CVar.AreCVarsLoaded = saved
	stub.state.cvarsLoaded = false
	local ok3, why = ns.Enum:Refresh()
	t("枚举:API 报未加载时拒绝", ok3 == false and why == "cvars-not-loaded", tostring(why))
	stub.state.cvarsLoaded = true
	ns.Enum:Refresh()
end

-- diag:管线回环 OK、扫描零拒绝(桩里大量策展键不存在,missing 属预期)
do
	local dlines = ns.SelfTest:Diag()
	local pipeOK, sweepLine = false, nil
	for _, l in ipairs(dlines) do
		if l:find("pipeline=OK", 1, true) then pipeOK = true end
		if l:find("sweep:", 1, true) then sweepLine = l end
	end
	t("diag:管线回环 OK", pipeOK, dlines[3])
	t("diag:扫描零拒绝", sweepLine and sweepLine:find("rejected=0", 1, true) ~= nil, sweepLine)
end

-- dump
ns.SelfTest:Dump()
t("dump:计数一致", ns.db.global.dump and ns.db.global.dump.count == CVAR_TOTAL)
t("dump:secure 位保留", ns.db.global.dump.cvars["nameplateMaxDistance"].s == 1)

-- T2 命名快照:建立、diff 五类口径、选择性恢复(走写管线可撤销)、上限淘汰
local s1 = ns.Snapshots:Create("before")
t("快照:建立且全量计数", s1 ~= nil and s1.count == CVAR_TOTAL and #ns.Snapshots:List() == 1)
for i = 901, 920 do
	E:Set("cvar", "dummyCvar" .. i, "7", "test")
end
local d = ns.Snapshots:Diff(s1.cvars, ns.Snapshots:CurrentCvars())
t("快照:diff 检出 20 项值变", #d.changed == 20 and #d.added == 0 and #d.removed == 0
	and #d.scopeDrift == 0 and #d.secureDrift == 0,
	string.format("c=%d a=%d r=%d", #d.changed, #d.added, #d.removed))
t("快照:值变行带双方值", d.changed[1].from == "0" and d.changed[1].to == "7")
local keys = {}
for i = 901, 910 do keys[#keys + 1] = "dummyCvar" .. i end
local rn, rfailed = ns.Snapshots:Restore(s1, keys)
t("快照:选择性恢复", rn == 10 and rfailed == 0
	and C_CVar.GetCVar("dummyCvar901") == "0" and C_CVar.GetCVar("dummyCvar911") == "7")
t("快照:恢复记入期望态", ns.db.profile.cvar["dummyCvar901"] == "0")
r = E:UndoLast()
t("快照:恢复可撤销", r == "applied" and C_CVar.GetCVar("dummyCvar910") == "7")
d = ns.Snapshots:Diff(s1.cvars, ns.Snapshots:CurrentCvars())
t("快照:恢复后 diff 收敛", #d.changed == 11, #d.changed)
for i = 901, 920 do
	E:Set("cvar", "dummyCvar" .. i, "0", "test")
	ns.db.profile.cvar["dummyCvar" .. i] = nil
end
for i = 2, 10 do ns.Snapshots:Create("s" .. i) end
t("快照:建满 10 份", #ns.Snapshots:List() == 10)
local sx, xerr = ns.Snapshots:Create("overflow")
t("快照:超限拒绝待确认", sx == nil and xerr == "full")
t("快照:最旧的是 before", ns.Snapshots:Oldest() == s1)
sx = ns.Snapshots:Create("overflow", true)
local s1Alive = false
for _, sn in ipairs(ns.Snapshots:List()) do
	if sn == s1 then s1Alive = true end
end
t("快照:确认后淘汰最旧份", sx ~= nil and #ns.Snapshots:List() == 10 and not s1Alive)
t("快照:删除", ns.Snapshots:Delete(sx) and #ns.Snapshots:List() == 9)

-- v0.3 聊天窗口域:全量快照回环 + 战斗锁
local cwsnap = ns.Adapters.chatwindow:Serialize()
t("chatwindow:导出窗口/消息组/频道", cwsnap[1].name == "General" and cwsnap[1].size == 14
	and cwsnap[1].messages[2] == "YELL" and cwsnap[1].channels[1] == "General"
	and cwsnap[2].name == "Log" and #cwsnap == 10)
stub.chatWindows[1].name = "Messed"
stub.chatWindows[1].size = 20
stub.chatWindows[1].messages = { "GUILD", "PARTY" }
stub.chatWindows[1].channels = { "Trade" }
ns.Adapters.chatwindow:Restore(cwsnap)
t("chatwindow:导入回环", stub.chatWindows[1].name == "General" and stub.chatWindows[1].size == 14
	and #stub.chatWindows[1].messages == 2 and stub.chatWindows[1].messages[1] == "SAY"
	and #stub.chatWindows[1].channels == 1 and stub.chatWindows[1].channels[1] == "General")
stub.state.inCombat = true
t("chatwindow:战斗锁 Restore 拒绝", ns.Adapters.chatwindow:Restore(cwsnap) == false)
stub.state.inCombat = false

-- v0.3 推荐包:结构约束(只推荐策展项)+ 预览 + 应用 + 整包撤销
do
	local curatedKeys = {}
	local function walk(controls)
		for _, c in ipairs(controls) do
			if c.domain == "cvar" then curatedKeys[c.key] = true end
			if c.children then walk(c.children) end
		end
	end
	for _, th in ipairs(ns.Data.themes) do walk(th.controls) end
	local bad
	for _, pack in ipairs(ns.Data.packs) do
		if not (pack.key and pack.title and pack.title.zh and pack.title.en
			and pack.text and pack.text.zh ~= "" and pack.text.en ~= "" and #pack.values > 0) then
			bad = pack.key or "?"
		end
		for _, item in ipairs(pack.values) do
			if not curatedKeys[item.key] then bad = tostring(pack.key) .. ":" .. tostring(item.key) end
			if type(item.value) ~= "string" then bad = tostring(pack.key) .. ":" .. tostring(item.key) .. ":value" end
		end
	end
	t("推荐包:四个包结构完整且只引用策展项", #ns.Data.packs == 4 and bad == nil, bad)
	-- 图标按 pack-<key>.png 约定放 Media/,PackPage 据此加载;新加包必须配图标
	local missingIcon
	for _, pack in ipairs(ns.Data.packs) do
		local fh = io.open(ROOT .. "/Media/pack-" .. pack.key .. ".png", "rb")
		if fh then fh:close() else missingIcon = pack.key end
	end
	t("推荐包:图标文件齐全", missingIcon == nil, missingIcon)
end
local pvpPack
for _, p in ipairs(ns.Data.packs) do
	if p.key == "pvpinfo" then pvpPack = p end
end
local pchanges = ns.Packs:Preview(pvpPack)
t("推荐包:预览只列有差异的项", #pchanges == 3, #pchanges)
local pApplied, pQueued, pFailed = ns.Packs:Apply(pvpPack)
t("推荐包:应用生效且进期望态", pFailed == 0 and C_CVar.GetCVar("nameplateShowEnemyPets") == "1"
	and ns.db.profile.cvar["nameplateShowEnemyTotems"] == "1")
local packEntry
do
	local log = ns.db.global.undoLog
	for i = 0, 499 do
		local p = ((log.head - 2 - i) % 500) + 1
		local e = log.entries[p]
		if not e then break end
		if e.bulk and e.new == "pack:pvpinfo" and not e.undone then packEntry = e break end
	end
end
r = E:Undo(packEntry)
t("推荐包:整包撤销回环", r == "applied" and C_CVar.GetCVar("nameplateShowEnemyPets") == "0"
	and C_CVar.GetCVar("nameplateShowEnemyGuardians") == "0")
for _, item in ipairs(pvpPack.values) do
	ns.db.profile.cvar[item.key] = nil
end
-- 旧客户端(12.0.7 类)没有的键:预览计 unknown,应用直接跳过不计失败
do
	local fake = { key = "fake", values = { { key = "noSuchCvarOnThisClient", value = "1" } } }
	local ch, unknown = ns.Packs:Preview(fake)
	local fa, fq, ff = ns.Packs:Apply(fake)
	t("推荐包:不存在的键预览计 unknown、应用跳过", #ch == 0 and unknown == 1
		and fa == 0 and fq == 0 and ff == 0)
end

-- v0.3 拼音搜索:字表就位,全拼与首字母缩写命中策展项
t("拼音:字表就位", ns.Data.pinyin and ns.Data.pinyin["姓"] == "xing")
ns.Search:Rebuild()
do
	local hits = ns.Search:Query("xingmingban")
	local found = false
	for _, it in ipairs(hits) do
		if it.key == "nameplateMaxDistance" then found = true end
	end
	t("拼音:全拼命中姓名板", found, #hits)
	local h2 = ns.Search:Query("yuanshishubiao")
	t("拼音:全拼命中原始鼠标输入", #h2 >= 1 and h2[1].key == "rawMouseEnable", h2[1] and h2[1].key)
end

-- T3 冲突检测:外部来源跨登录覆盖 >=3 次判冲突,同登录只计一次,两种处置
E:Set("cvar", "dummyCvar30", "1", "user")
local function externalOverwrite()
	stub.state.stackAddon = "GreedyAddon"
	C_CVar.SetCVar("dummyCvar30", "0")
	stub.state.stackAddon = nil
end
for i = 1, 2 do
	externalOverwrite()
	stub.fire("PLAYER_LOGIN")
end
t("冲突:2 登录未达阈值", #ns.Conflicts:List() == 0)
externalOverwrite()
stub.fire("PLAYER_LOGIN")
local conflicts = ns.Conflicts:List()
t("冲突:3 登录达阈值", #conflicts == 1 and conflicts[1].key == "dummyCvar30"
	and conflicts[1].by == "GreedyAddon" and conflicts[1].logins == 3,
	conflicts[1] and (conflicts[1].key .. "/" .. tostring(conflicts[1].by) .. "/" .. tostring(conflicts[1].logins)))
t("冲突:重放已改回期望值", C_CVar.GetCVar("dummyCvar30") == "1")
externalOverwrite()
ns.Replay:Assert()
t("冲突:同登录内 Assert 不重复计数", ns.Conflicts:List()[1].logins == 3)
ns.Conflicts:Acknowledge("dummyCvar30", "GreedyAddon")
t("冲突:保持处置后计数清零且仍管理", #ns.Conflicts:List() == 0
	and ns.db.profile.cvar["dummyCvar30"] == "1")
for i = 1, 3 do
	externalOverwrite()
	stub.fire("PLAYER_LOGIN")
end
t("冲突:保持后重新计数再达阈值", #ns.Conflicts:List() == 1)
ns.Conflicts:StopManaging("dummyCvar30")
t("冲突:停止管理清期望态与记录", ns.db.profile.cvar["dummyCvar30"] == nil
	and #ns.Conflicts:List() == 0)
E:Set("cvar", "dummyCvar30", "0", "test")

print(string.format("== %s ==", fails == 0 and "ALL PASS" or (fails .. " FAILED")))
if fails > 0 then error(fails .. " test(s) failed", 0) end
