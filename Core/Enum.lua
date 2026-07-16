local ADDON, ns = ...

local M = { cache = {}, count = 0, loaded = false }
ns.Enum = M

local function scopeOf(sAcc, sChar)
	if sAcc then return "account" elseif sChar then return "character" else return "machine" end
end

local function makeEntry(value, default, sAcc, sChar, locked, secure, readonly, help, category)
	return {
		value = value, default = default,
		scope = scopeOf(sAcc, sChar),
		serverAccount = sAcc or false, serverCharacter = sChar or false,
		locked = locked or false, secure = secure or false, readonly = readonly or false,
		help = help or "", category = category,
	}
end

-- 登录早期枚举不全是 AIO #126 根因之一:每次打开面板都要重新调用本函数回灌
function M:Refresh()
	if not (C_CVar.AreCVarsLoaded and C_CVar.AreCVarsLoaded()) then
		return false, "cvars-not-loaded"
	end
	local cmds = ConsoleGetAllCommands()
	local cvarType = Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
	wipe(self.cache)
	local n = 0
	for i = 1, #cmds do
		local c = cmds[i]
		if c.commandType == cvarType then
			local value, default, sAcc, sChar, locked, secure, readonly = C_CVar.GetCVarInfo(c.command)
			if value ~= nil or default ~= nil then
				n = n + 1
				self.cache[c.command] = makeEntry(value, default, sAcc, sChar, locked, secure, readonly, c.help, c.category)
			end
		end
	end
	self.count = n
	self.loaded = true
	return true, n
end

function M:Get(name)
	local e = self.cache[name]
	if not e then
		local value, default, sAcc, sChar, locked, secure, readonly = C_CVar.GetCVarInfo(name)
		if value == nil and default == nil then return nil end
		e = makeEntry(value, default, sAcc, sChar, locked, secure, readonly)
		self.cache[name] = e
	end
	return e
end

function M:OnExternalUpdate(name, value)
	local e = self.cache[name]
	if e then e.value = value end
end
