local ADDON, ns = ...

local M = {}
ns.SelfTest = M

local SECURE_CANDIDATES = { "nameplateMaxDistance", "nameplateOtherTopInset" }
local SERVER_CANDIDATES = { "alwaysCompareItems", "breakUpLargeNumbers", "autoLootDefault" }

local results

local function check(name, ok, detail)
	results[#results + 1] = { name = name, ok = ok and true or false, detail = detail }
end

local function report()
	local pass, fail = 0, 0
	for _, r in ipairs(results) do
		if r.ok then
			pass = pass + 1
			print(string.format("|cff00ff00PASS|r %s", r.name))
		else
			fail = fail + 1
			print(string.format("|cffff0000FAIL|r %s%s", r.name, r.detail and (" [" .. tostring(r.detail) .. "]") or ""))
		end
	end
	ns.Print(string.format("自测完成:%d 过 / %d 挂", pass, fail))
	if fail == 0 then
		ns.Print("合规复查提醒:/console taintLog 2 与 addonCombatRestrictionsForced 1 开着再过一遍主流程")
	end
	return fail == 0
end

-- 写入、撤销、回默认三步回环;结束后把值与期望态都恢复到进入前的状态
local function roundtrip(label, key, target)
	local info = ns.Enum:Get(key)
	if not info then
		check(label .. ":存在", false, key .. " 未找到")
		return
	end
	local old = ns.Adapters.cvar:Read(key)
	local prevDesired = ns.db.profile.cvar[key]

	local r = ns.Engine:Set("cvar", key, target, "test")
	check(label .. ":写入", r == "applied" and ns.Adapters.cvar:Read(key) == target,
		string.format("r=%s cur=%s want=%s", tostring(r), tostring(ns.Adapters.cvar:Read(key)), tostring(target)))

	local entry = ns.Engine:LastEntry()
	r = ns.Engine:Undo(entry)
	check(label .. ":撤销", r == "applied" and ns.Adapters.cvar:Read(key) == old,
		string.format("cur=%s want=%s", tostring(ns.Adapters.cvar:Read(key)), tostring(old)))

	r = ns.Engine:ResetToDefault("cvar", key)
	local def = ns.Adapters.cvar:Default(key)
	check(label .. ":回默认", r == "applied" and ns.Adapters.cvar:Read(key) == def,
		string.format("cur=%s def=%s", tostring(ns.Adapters.cvar:Read(key)), tostring(def)))

	if ns.Adapters.cvar:Read(key) ~= old then
		ns.Engine:Set("cvar", key, old, "test")
	end
	ns.db.profile.cvar[key] = prevDesired
end

local function pickSecure()
	for _, key in ipairs(SECURE_CANDIDATES) do
		local info = ns.Enum:Get(key)
		if info and info.secure and not info.readonly then return key end
	end
	for key, info in pairs(ns.Enum.cache) do
		if info.secure and not info.readonly and tonumber(info.value) then return key end
	end
end

local function pickServerStored()
	for _, key in ipairs(SERVER_CANDIDATES) do
		local info = ns.Enum:Get(key)
		if info and (info.serverAccount or info.serverCharacter) and not info.readonly
			and (info.value == "0" or info.value == "1") then
			return key
		end
	end
end

-- 第三组跨重登:phase A 写标记后需要重登,phase B 验证值存活并复原
local function replaySurvival()
	local marker = ns.db.global.selftest
	if marker then
		local cur = ns.Adapters.cvar:Read(marker.key)
		check("重放存活:" .. marker.key .. " 重登后仍为 " .. marker.want, cur == marker.want,
			string.format("cur=%s", tostring(cur)))
		ns.Engine:Set("cvar", marker.key, marker.old, "test")
		ns.db.profile.cvar[marker.key] = nil
		ns.db.global.selftest = nil
		ns.Print("第三组完成,测试值已复原")
	else
		local key = pickServerStored()
		if not key then
			check("重放存活:找到服务器存储候选", false, "候选全不可用")
			return
		end
		local old = ns.Adapters.cvar:Read(key)
		local want = old == "1" and "0" or "1"
		local r = ns.Engine:Set("cvar", key, want, "test")
		if r == "applied" then
			ns.db.global.selftest = { key = key, old = old, want = want, t = time() }
			ns.Print(string.format("第三组已布置:%s 改为 %s,请重登后再跑 /sh test 完成验证", key, want))
		else
			check("重放存活:布置写入", false, key .. " 写入失败")
		end
	end
end

function M:Run()
	results = {}

	local ok, n = ns.Enum:Refresh()
	check(string.format("枚举:>=1600 (实得 %s)", tostring(n)), ok and n >= 1600, not ok and n or nil)

	roundtrip("普通CVar(cameraZoomSpeed)", "cameraZoomSpeed",
		ns.Adapters.cvar:Read("cameraZoomSpeed") == "1" and "1.5" or "1")

	if InCombatLockdown() then
		check("secureCVar:需在脱战状态跑", false, "当前在战斗中")
	else
		local skey = pickSecure()
		if skey then
			local cur = ns.Adapters.cvar:Read(skey)
			roundtrip("secureCVar(" .. skey .. ")", skey, cur == "41" and "40" or "41")
		else
			check("secureCVar:找到候选", false, "无可用 secure 项")
		end
	end

	replaySurvival()

	return report()
end

-- P7 元数据管线入口:全量落盘供仓库脚本 diff
function M:Dump()
	local ok, n = ns.Enum:Refresh()
	if not ok then
		ns.Print("CVar 尚未加载完,稍后再试")
		return
	end
	local cvars = {}
	for name, e in pairs(ns.Enum.cache) do
		cvars[name] = {
			d = e.default,
			a = e.serverAccount and 1 or nil,
			c = e.serverCharacter and 1 or nil,
			s = e.secure and 1 or nil,
			r = e.readonly and 1 or nil,
			h = e.help ~= "" and e.help or nil,
		}
	end
	local _, build = GetBuildInfo()
	ns.db.global.dump = { t = time(), build = build, version = (GetBuildInfo()), count = n, cvars = cvars }
	ns.Print(string.format("已落盘 %d 条 CVar 到 SavedVariables(SettingsHubDB.global.dump),退出游戏后可被仓库脚本读取", n))
end
