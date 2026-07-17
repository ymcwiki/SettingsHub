local ADDON, ns = ...

-- T2 命名快照:全量枚举值(不只本插件改过的)落 SV,上限 10 份;
-- diff 复用 dump_diff.py 的五类口径(新增/删除/值变/scope 漂移/secure 漂移),
-- 恢复逐条走写管线(source=snapshot,可撤销、记期望态)
local M = { MAX = 10 }
ns.Snapshots = M

local function snaps()
	return ns.db.global.snapshots
end

function M:List()
	return snaps()
end

local function packEntry(e)
	return {
		v = e.value,
		a = e.serverAccount and 1 or nil,
		c = e.serverCharacter and 1 or nil,
		s = e.secure and 1 or nil,
	}
end

-- 当前实机状态按快照同构打包,供「与当前对比」用
function M:CurrentCvars()
	local out = {}
	for key, e in pairs(ns.Enum.cache) do
		out[key] = packEntry(e)
	end
	return out
end

function M:Create(name, evictOldest)
	local ok, err = ns.Enum:Refresh()
	if not ok then return nil, err end
	local s = snaps()
	if #s >= self.MAX then
		if not evictOldest then return nil, "full" end
		local oldest = 1
		for i = 2, #s do
			if s[i].t < s[oldest].t then oldest = i end
		end
		table.remove(s, oldest)
	end
	local _, build = GetBuildInfo()
	local snap = {
		name = name, t = time(), build = build, version = (GetBuildInfo()),
		count = ns.Enum.count, cvars = self:CurrentCvars(),
	}
	s[#s + 1] = snap
	return snap
end

function M:Oldest()
	local s = snaps()
	local oldest
	for _, snap in ipairs(s) do
		if not oldest or snap.t < oldest.t then oldest = snap end
	end
	return oldest
end

function M:Delete(snap)
	local s = snaps()
	for i, x in ipairs(s) do
		if x == snap then
			table.remove(s, i)
			return true
		end
	end
	return false
end

local function scopeOf(e)
	if e.a then return "account" elseif e.c then return "character" else return "machine" end
end

-- from 通常是较旧的快照,to 是当前或较新的快照;changed 行携带双方值供选择性恢复
function M:Diff(fromCvars, toCvars)
	local d = { added = {}, removed = {}, changed = {}, scopeDrift = {}, secureDrift = {} }
	for key, e in pairs(toCvars) do
		local o = fromCvars[key]
		if not o then
			d.added[#d.added + 1] = key
		else
			if o.v ~= e.v then
				d.changed[#d.changed + 1] = { key = key, from = o.v, to = e.v }
			end
			if scopeOf(o) ~= scopeOf(e) then
				d.scopeDrift[#d.scopeDrift + 1] = { key = key, from = scopeOf(o), to = scopeOf(e) }
			end
			if (o.s and true or false) ~= (e.s and true or false) then
				d.secureDrift[#d.secureDrift + 1] = { key = key, from = o.s and true or false, to = e.s and true or false }
			end
		end
	end
	for key in pairs(fromCvars) do
		if not toCvars[key] then d.removed[#d.removed + 1] = key end
	end
	table.sort(d.added)
	table.sort(d.removed)
	local byKey = function(a, b) return a.key < b.key end
	table.sort(d.changed, byKey)
	table.sort(d.scopeDrift, byKey)
	table.sort(d.secureDrift, byKey)
	return d
end

-- 选择性恢复:把快照里这些 key 的值逐条写回(全程可撤销,进期望态)
function M:Restore(snap, keys)
	local n, failed = 0, 0
	for _, key in ipairs(keys) do
		local e = snap.cvars[key]
		if e and e.v ~= nil then
			local r = ns.Engine:Set("cvar", key, e.v, "snapshot")
			if r == "failed" then failed = failed + 1 else n = n + 1 end
		end
	end
	return n, failed
end
