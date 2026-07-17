local ADDON, ns = ...

local M = {}
ns.Blame = M

local function callerAddon()
	local stack = debugstack(3, 12, 0)
	if not stack then return nil end
	for name in stack:gmatch("AddOns[/\\]([^/\\]+)[/\\]") do
		if name ~= ADDON then return name end
	end
	return nil
end

function M:Init()
	-- hooksecurefunc 只观察不拦截,无 taint 传染;暴雪 deprecated 包装 SetCVar 也经由
	-- C_CVar 表动态查成员,同样会触发本 hook(AIO 验证过的方案)
	if self.hooked then return end
	self.hooked = true
	hooksecurefunc(C_CVar, "SetCVar", function(name)
		if ns.Engine._selfWriting then return end
		ns.db.global.blame[name] = { by = callerAddon() or ns.L["Blizzard/script"], t = time() }
	end)
end

function M:Get(name)
	return ns.db.global.blame[name]
end
