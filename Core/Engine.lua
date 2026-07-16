local ADDON, ns = ...

local M = { failures = {}, _selfWriting = false, listeners = {} }
ns.Engine = M

local RING_SIZE = 500
-- 这些来源的成功写入会记入期望态(db.profile.cvar),登录重放据此工作;
-- replay/test/undo/reset/uninstall 不记,undo 与 reset 对期望态有各自的显式语义
local DESIRED_SOURCES = { user = true, import = true, ["profile"] = true }

local function ring()
	return ns.db.global.undoLog
end

local function pushEntry(entry)
	local log = ring()
	log.entries[log.head] = entry
	log.head = log.head % RING_SIZE + 1
end

function M:AddListener(fn)
	self.listeners[fn] = true
end

function M:Notify(domain, key)
	for fn in pairs(self.listeners) do fn(domain, key) end
end

-- 统一写管线:一切写入(UI/导入/重放/撤销/还原)都走这里,顺序固定
function M:Set(domain, key, value, source)
	local adapter = ns.Adapters[domain]
	if not adapter then return "failed", "no-adapter:" .. tostring(domain) end

	if InCombatLockdown() and not adapter:IsCombatSafe(key) then
		ns.CombatQueue:Push(domain, key, value, source)
		self:Notify(domain, key)
		return "queued"
	end

	local old = adapter:Read(key)
	local bk = domain .. ":" .. key
	local baseline = ns.db.global.baseline
	local firstTouch = false
	if old ~= nil and baseline[bk] == nil then
		firstTouch = true
		baseline[bk] = old
	end

	local entry = { t = time(), domain = domain, key = key, old = old, new = value, source = source }
	if domain == "cvar" then
		entry.prevDesired = ns.db.profile.cvar[key]
	end
	pushEntry(entry)

	self._selfWriting = true
	local ok, err = adapter:Apply(key, value)
	self._selfWriting = false

	if not ok then
		entry.failed = true
		if firstTouch then baseline[bk] = nil end
		self.failures[#self.failures + 1] = {
			t = entry.t, domain = domain, key = key, value = value, err = err, source = source,
		}
		self:Notify(domain, key)
		return "failed", err
	end

	if domain == "cvar" and DESIRED_SOURCES[source] then
		ns.db.profile.cvar[key] = tostring(value)
	end
	self:Notify(domain, key)
	return "applied"
end

function M:LastEntry()
	local log = ring()
	local p = ((log.head - 2) % RING_SIZE) + 1
	return log.entries[p]
end

function M:Undo(entry)
	if entry.failed or entry.undone then return "failed", "not-undoable" end
	if entry.old == nil then return "failed", "no-old-value" end
	local r, err = self:Set(entry.domain, entry.key, entry.old, "undo")
	if r == "applied" then
		entry.undone = true
		if entry.domain == "cvar" then
			-- 恢复该写入发生前的期望态(可能为 nil,即当时未被本插件管理)
			ns.db.profile.cvar[entry.key] = entry.prevDesired
		end
	end
	return r, err
end

function M:UndoLast()
	local log = ring()
	for i = 0, RING_SIZE - 1 do
		local p = ((log.head - 2 - i) % RING_SIZE) + 1
		local e = log.entries[p]
		if not e then break end
		-- undo 产生的条目只是游标记录,连续撤销要跳过它继续回走,否则变成 redo 抖动
		if not e.undone and not e.failed and e.source ~= "undo" then
			local r = self:Undo(e)
			if r == "applied" then
				ns.Print(string.format("已撤销 %s,恢复为 %s", e.key, tostring(e.old)))
			end
			return r
		end
	end
	ns.Print("没有可撤销的写入")
	return "failed", "nothing-to-undo"
end

function M:ResetToDefault(domain, key)
	local adapter = ns.Adapters[domain]
	if not adapter or not adapter.Default then return "failed", "no-default" end
	local def = adapter:Default(key)
	if def == nil then return "failed", "no-default" end
	local r, err = self:Set(domain, key, def, "reset")
	if r == "applied" and domain == "cvar" then
		-- 回默认即停止管理该项:清期望态,不再重放
		ns.db.profile.cvar[key] = nil
	end
	return r, err
end

-- 一键全量还原/卸载还原共用:把 baseline 里全部首触原值写回
-- 迭代中 Set 不会改 baseline(bk 已存在则跳过首触记录),pairs 安全
function M:RestoreAll(source)
	source = source or "uninstall"
	local baseline = ns.db.global.baseline
	local n, failed = 0, 0
	for bk in pairs(baseline) do
		local domain, key = bk:match("^([^:]+):(.+)$")
		local r = self:Set(domain, key, baseline[bk], source)
		if r == "failed" then failed = failed + 1 else n = n + 1 end
	end
	wipe(baseline)
	wipe(ns.db.profile.cvar)
	return n, failed
end
