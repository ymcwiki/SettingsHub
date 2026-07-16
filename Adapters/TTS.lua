local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.tts = M

-- C_TTSSettings 读写对称;账号/角色作用域由 CVar TTSUseCharacterSettings 决定(那是 cvar 域的事)

function M:Read(key)
	if key == "speechRate" then return tostring(C_TTSSettings.GetSpeechRate()) end
	if key == "speechVolume" then return tostring(C_TTSSettings.GetSpeechVolume()) end
	local enumVal = Enum.TtsBoolSetting and Enum.TtsBoolSetting[key]
	if enumVal ~= nil then return C_TTSSettings.GetSetting(enumVal) and "1" or "0" end
	return nil
end

function M:Apply(key, value)
	if key == "speechRate" then
		C_TTSSettings.SetSpeechRate(tonumber(value))
	elseif key == "speechVolume" then
		C_TTSSettings.SetSpeechVolume(tonumber(value))
	else
		local enumVal = Enum.TtsBoolSetting and Enum.TtsBoolSetting[key]
		if enumVal == nil then return false, "unknown-key" end
		C_TTSSettings.SetSetting(enumVal, tostring(value) == "1")
	end
	return true
end

function M:Default()
	return nil
end

function M:Serialize()
	local out = {
		speechRate = C_TTSSettings.GetSpeechRate(),
		speechVolume = C_TTSSettings.GetSpeechVolume(),
		bools = {},
	}
	for name, enumVal in pairs(Enum.TtsBoolSetting or {}) do
		if type(enumVal) == "number" then
			out.bools[name] = C_TTSSettings.GetSetting(enumVal)
		end
	end
	return out
end

function M:Restore(snapshot)
	if snapshot.speechRate then C_TTSSettings.SetSpeechRate(snapshot.speechRate) end
	if snapshot.speechVolume then C_TTSSettings.SetSpeechVolume(snapshot.speechVolume) end
	for name, v in pairs(snapshot.bools or {}) do
		local enumVal = Enum.TtsBoolSetting and Enum.TtsBoolSetting[name]
		if enumVal ~= nil then C_TTSSettings.SetSetting(enumVal, v) end
	end
	return true
end

function M:IsCombatSafe()
	return true
end
