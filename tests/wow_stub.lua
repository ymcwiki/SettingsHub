-- WoW API 桩:只覆盖 P2~P6 引擎逻辑用到的面,Lua 5.1 语义
local stub = { state = { inCombat = false, cvarsLoaded = true, stackAddon = nil }, frames = {}, registry = {} }

function stub.addCvar(name, opts)
	opts = opts or {}
	stub.registry[name] = {
		value = opts.value or "0", default = opts.default or opts.value or "0",
		sAcc = opts.sAcc or false, sChar = opts.sChar or false,
		locked = opts.locked or false, secure = opts.secure or false, readonly = opts.readonly or false,
		help = opts.help or "", category = opts.category or 4,
		commandType = opts.commandType or 0,
	}
end

function stub.fire(event, ...)
	for _, f in ipairs(stub.frames) do
		if f.events[event] and f.onEvent then f.onEvent(f, event, ...) end
	end
end

local function deepcopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = deepcopy(v) end
	return out
end
stub.deepcopy = deepcopy

_G.wipe = function(t)
	for k in pairs(t) do t[k] = nil end
	return t
end
_G.time = os.time
_G.InCombatLockdown = function() return stub.state.inCombat end

_G.CreateFrame = function()
	local f = { events = {} }
	function f:RegisterEvent(e) self.events[e] = true end
	function f:UnregisterEvent(e) self.events[e] = nil end
	function f:SetScript(_, fn) self.onEvent = fn end
	stub.frames[#stub.frames + 1] = f
	return f
end

_G.Enum = { ConsoleCommandType = { Cvar = 0, Command = 1 } }

_G.ConsoleGetAllCommands = function()
	local out = {}
	for name, e in pairs(stub.registry) do
		out[#out + 1] = { command = name, help = e.help, category = e.category, commandType = e.commandType }
	end
	table.sort(out, function(a, b) return a.command < b.command end)
	return out
end

_G.C_CVar = {
	AreCVarsLoaded = function() return stub.state.cvarsLoaded end,
	GetCVar = function(name)
		local e = stub.registry[name]
		return e and e.value
	end,
	GetCVarDefault = function(name)
		local e = stub.registry[name]
		return e and e.default
	end,
	GetCVarInfo = function(name)
		local e = stub.registry[name]
		if not e then return nil end
		return e.value, e.default, e.sAcc, e.sChar, e.locked, e.secure, e.readonly
	end,
	SetCVar = function(name, v)
		local e = stub.registry[name]
		if not e or e.readonly or e.locked then return end
		if e.secure and stub.state.inCombat then return end
		e.value = tostring(v)
		stub.fire("CVAR_UPDATE", name, e.value)
		return true
	end,
}

_G.hooksecurefunc = function(tbl, name, hook)
	if type(tbl) == "string" then tbl, name, hook = _G, tbl, name end
	local orig = tbl[name]
	tbl[name] = function(...)
		local r1, r2 = orig(...)
		hook(...)
		return r1, r2
	end
end

_G.debugstack = function()
	if stub.state.stackAddon then
		return 'Interface/AddOns/' .. stub.state.stackAddon .. '/core.lua:12: in function <core.lua:10>'
	end
	return '[C]: in function `SetCVar`'
end

_G.SlashCmdList = {}
_G.GetBuildInfo = function() return "12.1.0", "58000", "Jan 1 2026", 120100 end

local fakeAceDB = {}
function fakeAceDB:New(_, defaults)
	return deepcopy(defaults)
end
_G.LibStub = setmetatable({}, { __call = function(_, major)
	if major == "AceDB-3.0" then return fakeAceDB end
	error("stub: no lib " .. tostring(major))
end })

return stub
