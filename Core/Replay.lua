local ADDON, ns = ...

local M = {}
ns.Replay = M

-- 只重放有漂移的项:machine 项存 Config.wtf 通常无漂移,自然跳过;
-- 服务器存储项若被后到同步覆盖(AIO #126 场景),在这里按期望态改回
local applyDesired

-- Profiles 切换后按新 profile 的期望态回灌 cvar 域
function M:ApplyDesired(source)
	return applyDesired(source)
end

function applyDesired(source)
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
		ns.Print(string.format("登录重放:补写 %d 项 CVar", n))
	end
	-- 无回读域按期望态全量重放(MuteSoundFile 仅会话级,console 命令多数不持久)
	local ce = ns.Adapters.consoleexec:ReplayAll()
	local ms = ns.Adapters.mutesound:ReplayAll()
	if ce + ms > 0 then
		ns.Print(string.format("登录重放:console 命令 %d 条,静音音效 %d 个", ce, ms))
	end
end

function M:Assert()
	if not ns.Enum.loaded then return end
	local n = applyDesired("replay")
	if n > 0 then
		ns.Print(string.format("进入世界断言:%d 项被外部覆盖,已按期望态改回", n))
	end
end
