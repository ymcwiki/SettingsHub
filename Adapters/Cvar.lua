local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.cvar = M

function M:Read(key)
	local v = C_CVar.GetCVar(key)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

function M:Apply(key, value)
	-- 11.2 起对非法/只读/战斗中 secure 项的写入静默失败(ReturnNothing),只能靠返回值判定
	local ok = C_CVar.SetCVar(key, tostring(value))
	if not ok then return false, "set-rejected" end
	return true
end

function M:Default(key)
	return C_CVar.GetCVarDefault(key)
end

function M:Serialize()
	local out = {}
	for k, v in pairs(ns.db.profile.cvar) do out[k] = v end
	return out
end

function M:Restore(snapshot)
	for k, v in pairs(snapshot) do
		ns.Engine:Set("cvar", k, v, "import")
	end
end

function M:IsCombatSafe(key)
	local info = ns.Enum:Get(key)
	return not (info and info.secure)
end
