local ADDON, ns = ...

local M = { items = {}, order = {} }
ns.CombatQueue = M

-- 同 key 重复入队时后写覆盖,保持首次入队的顺序
function M:Push(domain, key, value, source)
	local bk = domain .. ":" .. key
	if not self.items[bk] then
		self.order[#self.order + 1] = bk
	end
	self.items[bk] = { domain = domain, key = key, value = value, source = source }
end

function M:Flush()
	if not next(self.items) then return end
	local items, order = self.items, self.order
	self.items, self.order = {}, {}
	local n = 0
	for i = 1, #order do
		local it = items[order[i]]
		if it then
			ns.Engine:Set(it.domain, it.key, it.value, it.source)
			n = n + 1
		end
	end
	if n > 0 then
		ns.Print(string.format("脱战,已应用 %d 项排队的写入", n))
	end
end

function M:Size()
	return #self.order
end
