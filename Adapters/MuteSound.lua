local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.mutesound = M

-- MuteSoundFile 仅会话级生效,SavedVariables 存 fileID 列表登录重放;
-- 列表由本适配器自维护(Engine 的期望态桶不管这个域)

local function list()
	return ns.db.profile.mutesound
end

local function indexOf(fileID)
	for i, id in ipairs(list()) do
		if id == fileID then return i end
	end
end

function M:Read(key)
	return indexOf(tonumber(key)) and "1" or "0"
end

function M:Apply(key, value)
	local fileID = tonumber(key)
	if not fileID then return false, "bad-fileid" end
	if tostring(value) == "1" then
		MuteSoundFile(fileID)
		if not indexOf(fileID) then list()[#list() + 1] = fileID end
	else
		UnmuteSoundFile(fileID)
		local i = indexOf(fileID)
		if i then table.remove(list(), i) end
	end
	return true
end

function M:Default()
	return "0"
end

function M:Serialize()
	local out = {}
	for i, id in ipairs(list()) do out[i] = id end
	return out
end

function M:Restore(snapshot)
	for _, id in ipairs(snapshot) do
		ns.Engine:Set("mutesound", tostring(id), "1", "import")
	end
end

function M:IsCombatSafe()
	return true
end

-- 临时解除:本次会话不静音,列表保留,下次登录恢复静音
function M:TempUnmute(fileID)
	UnmuteSoundFile(fileID)
end

function M:ReplayAll()
	for _, id in ipairs(list()) do
		MuteSoundFile(id)
	end
	return #list()
end
