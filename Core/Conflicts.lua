local ADDON, ns = ...

-- T3 冲突检测:重放补写时把漂移归因到 blame 记录的来源,跨登录计数;
-- 同一 key 被同一外部来源在 >=3 个不同登录里覆盖判为冲突,处置见日志页冲突区
local M = { THRESHOLD = 3 }
ns.Conflicts = M

function M:OnLogin()
	local g = ns.db.global
	g.loginCounter = (g.loginCounter or 0) + 1
end

-- Replay 发现期望态漂移时调用;同一登录内(含载入屏 Assert)只计一次
function M:RecordDrift(key)
	local g = ns.db.global
	local blame = g.blame[key]
	local by = blame and blame.by or ns.L["unknown source"]
	g.conflicts[key] = g.conflicts[key] or {}
	local rec = g.conflicts[key][by]
	if not rec then
		rec = { logins = 0, last = 0 }
		g.conflicts[key][by] = rec
	end
	if rec.last < (g.loginCounter or 0) then
		rec.logins = rec.logins + 1
		rec.last = g.loginCounter or 0
	end
end

-- 达阈值的冲突条目,按覆盖登录数降序
function M:List()
	local out = {}
	for key, sources in pairs(ns.db.global.conflicts) do
		for by, rec in pairs(sources) do
			if rec.logins >= self.THRESHOLD then
				out[#out + 1] = { key = key, by = by, logins = rec.logins }
			end
		end
	end
	table.sort(out, function(a, b)
		if a.logins ~= b.logins then return a.logins > b.logins end
		return a.key < b.key
	end)
	return out
end

-- 处置一:停止管理该项(移出期望态,不再重放),冲突记录一并清除
function M:StopManaging(key)
	ns.db.profile.cvar[key] = nil
	ns.db.global.conflicts[key] = nil
end

-- 处置二:保持我的值(继续每次登录改回),计数清零重新观察
function M:Acknowledge(key, by)
	local sources = ns.db.global.conflicts[key]
	local rec = sources and sources[by]
	if rec then
		rec.logins = 0
		rec.last = ns.db.global.loginCounter or 0
	end
end
