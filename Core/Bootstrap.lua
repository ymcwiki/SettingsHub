local ADDON, ns = ...

function ns.Print(...)
	print("|cff33ff99SettingsHub|r:", ...)
end

local defaults = {
	global = {
		undoLog = { head = 1, entries = {} },
		baseline = {},
		blame = {},
	},
	profile = {
		domains = { cvar = true },
		cvar = {},
	},
}

ns.f = CreateFrame("Frame")
ns.f:RegisterEvent("ADDON_LOADED")
ns.f:RegisterEvent("PLAYER_LOGIN")
ns.f:RegisterEvent("PLAYER_ENTERING_WORLD")
ns.f:RegisterEvent("CVAR_UPDATE")
ns.f:RegisterEvent("PLAYER_REGEN_ENABLED")
ns.f:RegisterEvent("PLAYER_REGEN_DISABLED")

ns.f:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON then return end
		ns.db = LibStub("AceDB-3.0"):New("SettingsHubDB", defaults, true)
	elseif event == "PLAYER_LOGIN" then
		ns.Enum:Refresh()
		ns.Blame:Init()
		ns.Replay:OnLogin()
		if ns.Integration then ns.Integration:Register() end
	elseif event == "PLAYER_ENTERING_WORLD" then
		ns.Replay:Assert()
	elseif event == "CVAR_UPDATE" then
		local cvar, value = ...
		ns.Enum:OnExternalUpdate(cvar, value)
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.CombatQueue:Flush()
		if ns.UI then ns.UI:SetCombatLock(false) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ns.UI then ns.UI:SetCombatLock(true) end
	end
end)

SLASH_SETTINGSHUB1 = "/settingshub"
SLASH_SETTINGSHUB2 = "/sh"
SlashCmdList.SETTINGSHUB = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "test" then
		ns.SelfTest:Run()
	elseif msg == "dump" then
		ns.SelfTest:Dump()
	elseif msg == "undo" then
		ns.Engine:UndoLast()
	elseif msg == "" then
		if ns.UI then
			ns.UI:Toggle()
		else
			ns.Print("可用命令: /sh test | /sh dump | /sh undo")
		end
	else
		ns.Print("用法: /sh [test|dump|undo]")
	end
end

function SettingsHub_OnAddonCompartmentClick()
	if ns.UI then ns.UI:Toggle() end
end
