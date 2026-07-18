local ADDON, ns = ...

function ns.Print(...)
	print("|cff33ff99SettingsHub|r:", ...)
end

local defaults = {
	global = {
		undoLog = { head = 1, entries = {} },
		baseline = {},
		blame = {},
		snapshots = {},
		conflicts = {},
		loginCounter = 0,
		tipsDismissed = {},
		minimap = { angle = 220 },
		luaErrors = {},
		autoSwitch = {
			-- 角色轴 = AceDB 内建 profileKeys + char.baseProfile,不在此表
			scene = { enabled = false, map = {} },
			spec = { enabled = false, map = {} },
			resolution = { enabled = false, map = {} },
			onLeave = "prompt", -- prompt | restore | keep
		},
	},
	char = {
		baseProfile = nil,
	},
	profile = {
		domains = { cvar = true },
		cvar = {},
		consoleexec = {},
		mutesound = {},
	},
}

ns.f = CreateFrame("Frame")
ns.f:RegisterEvent("ADDON_LOADED")
ns.f:RegisterEvent("PLAYER_LOGIN")
ns.f:RegisterEvent("PLAYER_ENTERING_WORLD")
ns.f:RegisterEvent("CVAR_UPDATE")
ns.f:RegisterEvent("PLAYER_REGEN_ENABLED")
ns.f:RegisterEvent("PLAYER_REGEN_DISABLED")
ns.f:RegisterEvent("PLAYER_LOGOUT")
ns.f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ns.f:RegisterEvent("DISPLAY_SIZE_CHANGED")

ns.f:SetScript("OnEvent", ns.Guard(function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON then return end
		ns.db = LibStub("AceDB-3.0"):New("SettingsHubDB", defaults, true)
	elseif event == "PLAYER_LOGIN" then
		ns.Enum:Refresh()
		ns.Blame:Init()
		ns.Conflicts:OnLogin()
		ns.Trial:Arm()
		ns.Replay:OnLogin()
		if ns.Integration then ns.Integration:Register() end
	elseif event == "PLAYER_LOGOUT" then
		if ns.Trial:Active() then ns.Trial:Revert("logout") end
	elseif event == "PLAYER_ENTERING_WORLD" then
		ns.Replay:Assert()
		ns.Profiles:EvaluateContext()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		if ... == "player" or ... == nil then ns.Profiles:EvaluateContext() end
	elseif event == "DISPLAY_SIZE_CHANGED" then
		ns.Profiles:EvaluateContext()
	elseif event == "CVAR_UPDATE" then
		local cvar, value = ...
		ns.Enum:OnExternalUpdate(cvar, value)
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.CombatQueue:Flush()
		if ns.UI then ns.UI:SetCombatLock(false) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ns.UI then ns.UI:SetCombatLock(true) end
	end
end))

SLASH_SETTINGSHUB1 = "/settingshub"
SLASH_SETTINGSHUB2 = "/sh"
SlashCmdList.SETTINGSHUB = ns.Guard(function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "test" then
		ns.SelfTest:Run()
	elseif msg == "test relog" then
		-- 第三组会临时改一项服务器存储值直到重登验证,显式命令才跑
		ns.SelfTest:Run("relog")
	elseif msg == "dump" then
		ns.SelfTest:Dump()
	elseif msg == "diag" then
		ns.SelfTest:Diag()
	elseif msg == "probe" then
		ns.SelfTest:Probe()
	elseif msg == "undo" then
		ns.Engine:UndoLast()
	elseif msg == "" then
		if ns.UI then
			ns.UI:Toggle()
		else
			ns.Print(ns.L["Commands: /sh test | /sh dump | /sh undo | /sh diag | /sh probe"])
		end
	else
		ns.Print(ns.L["Usage: /sh [test|dump|undo|diag|probe]"])
	end
end)

function SettingsHub_OnAddonCompartmentClick()
	if ns.UI then ns.UI:Toggle() end
end
