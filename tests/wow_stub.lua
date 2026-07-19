-- WoW API 桩:只覆盖 P2~P6 引擎逻辑用到的面,Lua 5.1 语义
local stub = { state = {
	inCombat = false, cvarsLoaded = true, stackAddon = nil,
	version = "12.1.0", build = "58000",
}, frames = {}, registry = {} }

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

stub.loadedAddons = {}
function stub.setAddonLoaded(name, value) stub.loadedAddons[name] = value end
_G.C_AddOns = {
	IsAddOnLoaded = function(name) return stub.loadedAddons and stub.loadedAddons[name] or false end,
}
_G.IsAddOnLoaded = _G.C_AddOns.IsAddOnLoaded

-- UI 方法一律 no-op 兜底:测试只关心逻辑,不关心布局
local function uiNoop(t)
	return setmetatable(t or {}, { __index = function(tt, k)
		local fn = function() end
		rawset(tt, k, fn)
		return fn
	end })
end

_G.CreateFrame = function()
	local f = { events = {} }
	function f:RegisterEvent(e) self.events[e] = true end
	function f:UnregisterEvent(e) self.events[e] = nil end
	function f:SetScript(_, fn) self.onEvent = fn end
	function f:CreateFontString() return uiNoop() end
	stub.frames[#stub.frames + 1] = f
	return uiNoop(f)
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
_G.GetBuildInfo = function()
	return stub.state.version, stub.state.build, "Jan 1 2026", 120100
end
stub.timers = {}
_G.C_Timer = {
	After = function(sec, fn) stub.timers[#stub.timers + 1] = { at = sec, fn = fn } end,
}
_G.GetLocale = function() return stub.state.locale or "zhCN" end
_G.date = os.date

-- P5 非 CVar 域桩
stub.consoleLog = {}
_G.ConsoleExec = function(cmd) stub.consoleLog[#stub.consoleLog + 1] = cmd end

stub.muted = {}
_G.MuteSoundFile = function(id) stub.muted[id] = true end
_G.UnmuteSoundFile = function(id) stub.muted[id] = nil end

stub.keyToCmd = { SPACE = "JUMP", TAB = "TARGETNEARESTENEMY" }
stub.modifiedClicks = { SELFCAST = "ALT", FOCUSCAST = "NONE", AUTOLOOTTOGGLE = "SHIFT" }
stub.saveBindingsCalls = 0
local function bindingList()
	local cmds, keysByCmd = {}, {}
	for key, cmd in pairs(stub.keyToCmd) do
		if not keysByCmd[cmd] then keysByCmd[cmd] = {} cmds[#cmds + 1] = cmd end
		local ks = keysByCmd[cmd]
		ks[#ks + 1] = key
	end
	table.sort(cmds)
	for _, ks in pairs(keysByCmd) do table.sort(ks) end
	return cmds, keysByCmd
end
_G.GetNumBindings = function() local c = bindingList() return #c end
_G.GetBinding = function(i)
	local c, m = bindingList()
	local cmd = c[i]
	return cmd, "STUB", m[cmd][1], m[cmd][2]
end
_G.GetBindingKey = function(cmd)
	local _, m = bindingList()
	return m[cmd] and m[cmd][1]
end
_G.SetBinding = function(key, cmd) stub.keyToCmd[key] = cmd return 1 end
_G.SaveBindings = function() stub.saveBindingsCalls = stub.saveBindingsCalls + 1 end
_G.GetCurrentBindingSet = function() return 2 end
_G.GetModifiedClick = function(a) return stub.modifiedClicks[a] end
_G.SetModifiedClick = function(a, v) stub.modifiedClicks[a] = v end

local ACCOUNT_MAX = 120
stub.accountMacros = { { name = "AccMacro", icon = "icon1", body = "/dance" } }
stub.charMacros = { { name = "TestMacro", icon = "icon2", body = "/wave" } }
local function macroAt(i)
	if i <= ACCOUNT_MAX then return stub.accountMacros[i] end
	return stub.charMacros[i - ACCOUNT_MAX]
end
_G.GetNumMacros = function() return #stub.accountMacros, #stub.charMacros end
_G.GetMacroInfo = function(i)
	local m = macroAt(i)
	if m then return m.name, m.icon, m.body end
end
_G.GetMacroIndexByName = function(name)
	for i, m in ipairs(stub.accountMacros) do if m.name == name then return i end end
	for i, m in ipairs(stub.charMacros) do if m.name == name then return ACCOUNT_MAX + i end end
	return 0
end
_G.CreateMacro = function(name, icon, body, perChar)
	local list = perChar and stub.charMacros or stub.accountMacros
	list[#list + 1] = { name = name, icon = icon, body = body }
	return (perChar and ACCOUNT_MAX or 0) + #list
end
_G.EditMacro = function(i, name, icon, body)
	local m = macroAt(i)
	if m then m.name, m.icon, m.body = name, icon, body end
end
_G.DeleteMacro = function(i)
	if i <= ACCOUNT_MAX then table.remove(stub.accountMacros, i)
	else table.remove(stub.charMacros, i - ACCOUNT_MAX) end
end

_G.Enum.EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 }
stub.editMode = { activeLayout = 2, layouts = {
	{ layoutType = 0, layoutName = "Modern" },
	{ layoutType = 1, layoutName = "MyLayout", data = "blob1" },
} }
_G.C_EditMode = {
	GetLayouts = function() return deepcopy(stub.editMode) end,
	SaveLayouts = function(t) stub.editMode = deepcopy(t) end,
	SetActiveLayout = function(i) stub.editMode.activeLayout = i end,
	ConvertLayoutInfoToString = function(l) return "EMS:" .. (l.data or "") end,
	ConvertStringToLayoutInfo = function(s)
		local d = s:match("^EMS:(.*)$")
		if d then return { data = d } end
	end,
}

_G.Enum.ClickBindingType = { None = 0, Spell = 1, Macro = 2, Interaction = 3 }
stub.clickProfile = {
	{ type = 1, actionID = 133, button = "BUTTON1", modifiers = 0 },
	{ type = 2, actionID = 121, button = "BUTTON2", modifiers = 1 },
}
_G.C_ClickBindings = {
	GetProfileInfo = function() return deepcopy(stub.clickProfile) end,
	SetProfileByInfo = function(t) stub.clickProfile = deepcopy(t) end,
}

_G.Enum.TtsBoolSetting = { AudibleFeedback = 0, NarrateMyMessages = 2 }
stub.tts = { rate = 0, volume = 100, bools = { [0] = true, [2] = false } }
_G.C_TTSSettings = {
	GetSpeechRate = function() return stub.tts.rate end,
	SetSpeechRate = function(v) stub.tts.rate = v end,
	GetSpeechVolume = function() return stub.tts.volume end,
	SetSpeechVolume = function(v) stub.tts.volume = v end,
	GetSetting = function(e) return stub.tts.bools[e] end,
	SetSetting = function(e, v) stub.tts.bools[e] = v end,
}

-- 官方 Settings API 桩:NotifyUpdate 仿实机语义,带着注册表当前值回调监听器。
-- 12.0.7 实机「officialSearch 项勾选框点不动」的根因就靠这个语义复现,别简化成 no-op。
stub.addonSettings = {}
_G.Settings = {
	VarType = { Boolean = "Boolean" },
	RegisterCanvasLayoutCategory = function(_, name) return { name = name } end,
	RegisterVerticalLayoutCategory = function(name) return { name = name } end,
	RegisterAddOnCategory = function() end,
	RegisterAddOnSetting = function(_, variable, variableKey, variableTbl, _, _, _)
		local s = {}
		function s:GetValue() return variableTbl[variableKey] end
		function s:SetValue(v)
			variableTbl[variableKey] = v
			if self._cb then self._cb(self) end
		end
		function s:SetValueChangedCallback(cb) self._cb = cb end
		stub.addonSettings[variable] = s
		return s
	end,
	CreateCheckbox = function() return { AddSearchTags = function() end } end,
	NotifyUpdate = function(variable)
		local s = stub.addonSettings[variable]
		if s and s._cb then s._cb(s) end
	end,
}

-- 聊天窗口域桩(v0.3)
_G.NUM_CHAT_WINDOWS = 10
stub.chatWindows = {
	[1] = { name = "General", size = 14, r = 0, g = 0, b = 0, alpha = 0.25, shown = 1, locked = 1,
		docked = 1, uninteractable = 0, messages = { "SAY", "YELL" }, channels = { "General" } },
	[2] = { name = "Log", size = 12, r = 0, g = 0, b = 0, alpha = 0, shown = 0, locked = 0,
		docked = 2, uninteractable = 0, messages = { "GUILD" }, channels = {} },
}
local function chatWin(i)
	local w = stub.chatWindows[i]
	if not w then
		w = { name = "", size = 14, r = 0, g = 0, b = 0, alpha = 0, shown = 0, locked = 0,
			docked = 0, uninteractable = 0, messages = {}, channels = {} }
		stub.chatWindows[i] = w
	end
	return w
end
_G.GetChatWindowInfo = function(i)
	local w = chatWin(i)
	return w.name, w.size, w.r, w.g, w.b, w.alpha, w.shown == 1, w.locked == 1, w.docked, w.uninteractable == 1
end
_G.GetChatWindowMessages = function(i) return unpack(chatWin(i).messages) end
_G.GetChatWindowChannels = function(i)
	local out = {}
	for _, ch in ipairs(chatWin(i).channels) do
		out[#out + 1] = ch
		out[#out + 1] = 1
	end
	return unpack(out)
end
_G.SetChatWindowName = function(i, v) chatWin(i).name = v end
_G.SetChatWindowSize = function(i, v) chatWin(i).size = v end
_G.SetChatWindowColor = function(i, r, g, b) local w = chatWin(i) w.r, w.g, w.b = r, g, b end
_G.SetChatWindowAlpha = function(i, v) chatWin(i).alpha = v end
_G.SetChatWindowShown = function(i, v) chatWin(i).shown = v and 1 or 0 end
_G.SetChatWindowLocked = function(i, v) chatWin(i).locked = v and 1 or 0 end
_G.SetChatWindowDocked = function(i, v) chatWin(i).docked = v end
_G.SetChatWindowUninteractable = function(i, v) chatWin(i).uninteractable = v and 1 or 0 end
_G.AddChatWindowMessages = function(i, g) table.insert(chatWin(i).messages, g) end
_G.RemoveChatWindowMessages = function(i, g)
	local m = chatWin(i).messages
	for j, x in ipairs(m) do
		if x == g then table.remove(m, j) break end
	end
end
_G.AddChatWindowChannel = function(i, ch) table.insert(chatWin(i).channels, ch) end
_G.RemoveChatWindowChannel = function(i, ch)
	local m = chatWin(i).channels
	for j, x in ipairs(m) do
		if x == ch then table.remove(m, j) break end
	end
end

-- 四轴上下文
stub.state.instanceType = "none"
_G.IsInInstance = function()
	local t = stub.state.instanceType
	return t ~= "none", t
end
_G.GetNumSpecializations = function() return 2 end
_G.GetSpecialization = function() return stub.state.spec or 1 end
_G.GetSpecializationInfo = function(i) return 250 + i, "Spec" .. i end
_G.GetPhysicalScreenSize = function() return 2560, 1440 end

-- 真库:LibStub/LibSerialize/LibDeflate 直接用仓库里的实现(导入导出走真管线)
assert(ROOT, "stub 需要全局 ROOT 指向仓库根")
dofile(ROOT .. "/Libs/LibStub/LibStub.lua")
dofile(ROOT .. "/Libs/LibSerialize/LibSerialize.lua")
dofile(ROOT .. "/Libs/LibDeflate/LibDeflate.lua")

-- AceDB 桩:支持命名 profile 与 SetProfile(真 AceDB 依赖过多环境 API,桩到够用为止)
local AceDB = LibStub:NewLibrary("AceDB-3.0", 999)
function AceDB:New(_, defaults)
	local profiles = {}
	local db = { global = deepcopy(defaults.global), char = deepcopy(defaults.char or {}) }
	local current
	local function ensure(name)
		if not profiles[name] then profiles[name] = deepcopy(defaults.profile) end
		return profiles[name]
	end
	function db:SetProfile(name)
		current = name
		self.profile = ensure(name)
	end
	function db:GetCurrentProfile() return current end
	function db:GetProfiles()
		local out = {}
		for k in pairs(profiles) do out[#out + 1] = k end
		table.sort(out)
		return out, #out
	end
	db:SetProfile("Default")
	return db
end

return stub
