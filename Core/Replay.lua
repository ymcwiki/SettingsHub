local ADDON, ns = ...

local M = {}
ns.Replay = M

-- 只重放有漂移的项:machine 项存 Config.wtf 通常无漂移,自然跳过;
-- 服务器存储项若被后到同步覆盖(AIO #126 场景),在这里按期望态改回
local function applyDesired(source)
	local n = 0
	for key, want in pairs(ns.db.profile.cvar) do
		local info = ns.Enum:Get(key)
		if info and not info.readonly then
			local cur = ns.Adapters.cvar:Read(key)
			if cur ~= want then
				if ns.Engine:Set("cvar", key, want, source) == "applied" then
					n = n + 1
				end
			end
		end
	end
	return n
end

function M:OnLogin()
	local n = applyDesired("replay")
	if n > 0 then
		ns.Print(string.format("登录重放:补写 %d 项", n))
	end
end

function M:Assert()
	if not ns.Enum.loaded then return end
	local n = applyDesired("replay")
	if n > 0 then
		ns.Print(string.format("进入世界断言:%d 项被外部覆盖,已按期望态改回", n))
	end
end
