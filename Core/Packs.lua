local ADDON, ns = ...

-- v0.3 推荐包应用逻辑:预览产 diff,应用前 LogBulk 记受影响键的整体快照(日志页可整体撤销),
-- 然后逐条走写管线(source=pack,进期望态;secure 项战斗中自然排队)
local M = {}
ns.Packs = M

-- 与当前值对比:只列会发生变化的项;本客户端不存在的键计入 unknown 跳过
function M:Preview(pack)
	local changes, unknown = {}, 0
	for _, item in ipairs(pack.values) do
		local cur = ns.Adapters.cvar:Read(item.key)
		if cur == nil then
			unknown = unknown + 1
		elseif cur ~= item.value then
			changes[#changes + 1] = { key = item.key, old = cur, new = item.value }
		end
	end
	return changes, unknown
end

function M:Apply(pack)
	local snap = {}
	for _, item in ipairs(pack.values) do
		local cur = ns.Adapters.cvar:Read(item.key)
		if cur ~= nil then snap[item.key] = cur end
	end
	ns.Engine:LogBulk("cvar", snap, "pack:" .. pack.key)
	local applied, queued, failed = 0, 0, 0
	for _, item in ipairs(pack.values) do
		-- 本客户端不存在的键(旧版本)预览时已声明跳过,这里不写、不计失败
		if snap[item.key] ~= nil then
			local r = ns.Engine:Set("cvar", item.key, item.value, "pack")
			if r == "applied" then applied = applied + 1
			elseif r == "queued" then queued = queued + 1
			else failed = failed + 1 end
		end
	end
	return applied, queued, failed
end
