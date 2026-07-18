local ADDON, ns = ...

-- v0.4 试穿模式(DialogueUI 验证过的交互:批量临时改写 + 自动还原):
-- 应用走写管线但 source=trial 不进期望态;还原点 = 到期 / 登出 / 手动;
-- 还原表落 SV,崩溃后下次登录兜底还原;「转为常驻」把当前值记入期望态并解除试穿
local M = {}
ns.Trial = M

local function trial()
	return ns.db.global.trial
end

function M:Active()
	return trial()
end

-- values: { { key=, value= }, ... };已在试穿中则拒绝(一次一套,语义简单)
function M:Start(values, minutes, label)
	if trial() then return nil, "active" end
	local revert = {}
	for _, it in ipairs(values) do
		local cur = ns.Adapters.cvar:Read(it.key)
		if cur ~= nil then revert[it.key] = cur end
	end
	local applied = 0
	for _, it in ipairs(values) do
		if revert[it.key] ~= nil then
			if ns.Engine:Set("cvar", it.key, it.value, "trial") ~= "failed" then
				applied = applied + 1
			end
		end
	end
	ns.db.global.trial = { label = label, expires = time() + minutes * 60, revert = revert }
	self:Arm()
	return applied
end

-- 登录时也走这里:过期(含崩溃残留)立即还原,否则重新挂定时器
function M:Arm()
	local tr = trial()
	if not tr then return end
	local remain = tr.expires - time()
	if remain <= 0 then
		self:Revert("expired")
		return
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(remain, function()
			if trial() == tr then M:Revert("expired") end
		end)
	end
end

function M:Revert(reason)
	local tr = trial()
	if not tr then return 0 end
	local n = 0
	for key, old in pairs(tr.revert) do
		if ns.Engine:Set("cvar", key, old, "trial") == "applied" then
			tr.revert[key] = nil
			n = n + 1
		end
	end
	if next(tr.revert) == nil then
		ns.db.global.trial = nil
	else
		ns.db.global.trial = tr
	end
	ns.Print(string.format(ns.L["Trial [%s] reverted (%s), %d values restored"],
		tostring(tr.label), tostring(reason), n))
	if ns.UI then ns.UI:Refresh() end
	return n
end

-- 转为常驻:当前值记入期望态(登录重放会守住),不再还原
function M:Promote()
	local tr = trial()
	if not tr then return end
	local n = 0
	for key in pairs(tr.revert) do
		local cur = ns.Adapters.cvar:Read(key)
		if cur ~= nil then
			ns.db.profile.cvar[key] = cur
			n = n + 1
		end
	end
	ns.db.global.trial = nil
	ns.Print(string.format(ns.L["Trial [%s] promoted: %d values pinned to the active profile"],
		tostring(tr.label), n))
	if ns.UI then ns.UI:Refresh() end
end
