local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.binding = M

-- 键位与 ModifiedClick 合一:全部写操作 nocombat,提交统一走 SaveBindings(GetCurrentBindingSet())

local MODIFIED_CLICKS = { "SELFCAST", "FOCUSCAST", "AUTOLOOTTOGGLE" }

function M:Read(key)
	local mc = key:match("^MC:(.+)$")
	if mc then return GetModifiedClick(mc) end
	return (GetBindingKey(key))
end

function M:Apply(key, value)
	local mc = key:match("^MC:(.+)$")
	if mc then
		SetModifiedClick(mc, value)
	else
		if not SetBinding(value, key) then return false, "bind-rejected" end
	end
	SaveBindings(GetCurrentBindingSet())
	return true
end

function M:Default()
	return nil
end

function M:Serialize()
	local out = { bindings = {}, modified = {} }
	for i = 1, GetNumBindings() do
		local command, _, key1, key2 = GetBinding(i)
		if key1 then
			out.bindings[command] = { key1, key2 }
		end
	end
	for _, action in ipairs(MODIFIED_CLICKS) do
		out.modified[action] = GetModifiedClick(action)
	end
	return out
end

-- 按快照回灌:只补齐快照里的键,不清除快照外的既有绑定(破坏性清除留给用户手动)
function M:Restore(snapshot)
	if InCombatLockdown() then return false, "in-combat" end
	local n = 0
	for command, keys in pairs(snapshot.bindings or {}) do
		for _, key in ipairs(keys) do
			if SetBinding(key, command) then n = n + 1 end
		end
	end
	for action, value in pairs(snapshot.modified or {}) do
		SetModifiedClick(action, value)
	end
	SaveBindings(GetCurrentBindingSet())
	return true, n
end

function M:IsCombatSafe()
	return false
end
