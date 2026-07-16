local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.macro = M

-- 宏:账号 120 + 角色 30 槽位,建改删全部 nocombat;
-- 导入按名字重映射,新建导致的槽位漂移收集后显式提示(动作条引用槽位号的用户需要知道)

local ACCOUNT_MAX = 120

function M:Read(key)
	local idx = GetMacroIndexByName(key)
	if idx == 0 then return nil end
	local name, icon, body = GetMacroInfo(idx)
	return { name = name, icon = icon, body = body, index = idx }
end

function M:Apply(key, value)
	if InCombatLockdown() then return false, "in-combat" end
	local idx = GetMacroIndexByName(key)
	if value == nil then
		if idx == 0 then return false, "not-found" end
		DeleteMacro(idx)
		return true
	end
	if idx > 0 then
		EditMacro(idx, value.name or key, value.icon, value.body)
	else
		local newIdx = CreateMacro(value.name or key, value.icon or "INV_MISC_QUESTIONMARK", value.body, value.perCharacter)
		if not newIdx then return false, "create-failed" end
	end
	return true
end

function M:Default()
	return nil
end

function M:Serialize()
	local out = { account = {}, character = {} }
	local numAccount, numChar = GetNumMacros()
	for i = 1, numAccount do
		local name, icon, body = GetMacroInfo(i)
		if name then out.account[#out.account + 1] = { name = name, icon = icon, body = body, index = i } end
	end
	for i = ACCOUNT_MAX + 1, ACCOUNT_MAX + numChar do
		local name, icon, body = GetMacroInfo(i)
		if name then out.character[#out.character + 1] = { name = name, icon = icon, body = body, index = i } end
	end
	return out
end

function M:Restore(snapshot)
	if InCombatLockdown() then return false, "in-combat" end
	local drifted = {}
	local function restoreSet(macros, perCharacter)
		for _, m in ipairs(macros or {}) do
			local idx = GetMacroIndexByName(m.name)
			if idx > 0 then
				EditMacro(idx, m.name, m.icon, m.body)
			else
				idx = CreateMacro(m.name, m.icon or "INV_MISC_QUESTIONMARK", m.body, perCharacter)
			end
			if idx and m.index and idx ~= m.index then
				drifted[#drifted + 1] = string.format("%s(%d 变 %d)", m.name, m.index, idx)
			end
		end
	end
	restoreSet(snapshot.account, false)
	restoreSet(snapshot.character, true)
	if #drifted > 0 then
		ns.Print("宏槽位发生漂移(动作条上引用槽位号的按钮需要检查): " .. table.concat(drifted, ", "))
	end
	return true, #drifted
end

function M:IsCombatSafe()
	return false
end
