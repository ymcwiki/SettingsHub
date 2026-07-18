local ADDON, ns = ...

local M = { items = {}, order = {} }
ns.CombatQueue = M

-- 同 key 重复入队时后写覆盖,保持首次入队的顺序
function M:Push(domain, key, value, source, onApplied)
	local bk = domain .. ":" .. key
	if not self.items[bk] then
		self.order[#self.order + 1] = bk
	end
	self.items[bk] = { domain = domain, key = key, value = value, source = source, onApplied = onApplied }
end

function M:Flush()
	if not next(self.items) then return end
	local items, order = self.items, self.order
	self.items, self.order = {}, {}
	local applied, failed = 0, 0
	for i = 1, #order do
		local it = items[order[i]]
		if it then
			local r = ns.Engine:Set(it.domain, it.key, it.value, it.source)
			if r == "applied" then
				applied = applied + 1
				if it.onApplied then it.onApplied() end
			else
				failed = failed + 1
			end
		end
	end
	if applied > 0 then
		ns.Print(string.format(ns.L["Combat ended, applied %d queued writes"], applied))
	end
	if failed > 0 then
		ns.Print(string.format(ns.L["Combat ended, %d queued writes failed"], failed))
	end
end

function M:Size()
	return #self.order
end
