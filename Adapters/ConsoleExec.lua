local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.consoleexec = M

-- console 命令无 getter,fire-and-forget:Read 返回记录的期望态,UI 必须明示无法回读校验

local allowedConsole

local function collectAllowed(controls)
	for _, control in ipairs(controls or {}) do
		if control.domain == "consoleexec" and type(control.key) == "string" then
			allowedConsole[control.key] = true
		end
		if control.children then collectAllowed(control.children) end
	end
end

function M:IsAllowed(key)
	if not allowedConsole then
		if not ns.Data or not ns.Data.themes then return false end
		allowedConsole = {}
		for _, theme in ipairs(ns.Data.themes) do collectAllowed(theme.controls) end
	end
	return allowedConsole[key] == true
end

function M:Read(key)
	return ns.db.profile.consoleexec[key]
end

function M:Apply(key, value)
	if not self:IsAllowed(key) then return false, "not-allowlisted" end
	if ConsoleExec(key .. " " .. tostring(value)) ~= true then
		return false, "console-rejected"
	end
	return true
end

function M:Default()
	return nil
end

function M:Serialize()
	local out = {}
	for k, v in pairs(ns.db.profile.consoleexec) do out[k] = v end
	return out
end

function M:Restore(snapshot)
	for k, v in pairs(snapshot) do
		ns.Engine:Set("consoleexec", k, v, "import")
	end
end

function M:IsCombatSafe()
	return true
end

-- 登录重放:期望态即命令表,逐条执行(Read 恒等于期望态,不能走 diff 路径)
function M:ReplayAll()
	local n = 0
	for k, v in pairs(ns.db.profile.consoleexec) do
		if self:IsAllowed(k) and ns.Engine:Set("consoleexec", k, v, "replay") == "applied" then
			n = n + 1
		end
	end
	return n
end
