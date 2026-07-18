local ADDON, ns = ...

local M = { contextAxis = nil, _knownProfiles = {} }
ns.Profiles = M

-- 批量域:profile 存 Serialize 快照,应用时整域 Restore(先 LogBulk 记撤销快照)
local BULK_DOMAINS = { "binding", "macro", "editmode", "clickbinding", "tts", "chatwindow" }
M.BULK_DOMAINS = BULK_DOMAINS
M.SCENES = { "party", "raid", "arena", "pvp", "world" }

local MAX_COMPRESSED = 256 * 1024
local MAX_SERIALIZED = 2 * 1024 * 1024
local MAX_ENTRIES = 50000

local function autoCfg()
	return ns.db.global.autoSwitch
end

local function hasBulkDomains(profile)
	if not profile or not profile.domains then return false end
	for _, d in ipairs(BULK_DOMAINS) do
		if profile.domains[d] and profile[d] then return true end
	end
	return false
end

local function importHasBulkDomains(payload)
	for _, d in ipairs(BULK_DOMAINS) do
		if payload.data[d] ~= nil then return true end
	end
	return false
end

function M:Current()
	return ns.db:GetCurrentProfile()
end

function M:List()
	return ns.db:GetProfiles()
end

function M:CaptureDomain(domain)
	local snap = ns.Adapters[domain]:Serialize()
	if snap == nil then
		ns.Print(string.format(ns.L["%s has nothing to capture right now"], domain))
		return
	end
	ns.db.profile[domain] = snap
	ns.db.profile.domains[domain] = true
	ns.Print(string.format(ns.L["%s domain captured into profile [%s]"], domain, self:Current()))
end

function M:Pin(domain, key)
	if domain ~= "cvar" then return end
	local v = ns.Adapters.cvar:Read(key)
	if v ~= nil then
		ns.db.profile.cvar[key] = v
		ns.Print(string.format(ns.L["%s = %s pinned to profile [%s]"], key, v, self:Current()))
	end
end

-- 把激活 profile 的内容应用到实机
function M:ApplyActive(label)
	if InCombatLockdown() and hasBulkDomains(ns.db.profile) then
		ns.Print(ns.L["Cannot apply a profile with bulk domains during combat; try again after combat"])
		return false, "in-combat-bulk"
	end
	ns.Replay:ApplyDesired("profile")
	ns.Adapters.consoleexec:ReplayAll()
	for _, d in ipairs(BULK_DOMAINS) do
		if ns.db.profile.domains[d] and ns.db.profile[d] then
			ns.Engine:LogBulk(d, ns.Adapters[d]:Serialize(), label)
			ns.Adapters[d]:Restore(ns.db.profile[d])
		end
	end
end

-- 切换语义(P6):应用前先快照当前活动值入撤销日志;手动切换更新角色基准 profile
function M:Switch(name, reason, isContext)
	if ns.db:GetCurrentProfile() == name then return end
	self._knownProfiles[ns.db:GetCurrentProfile()] = ns.db.profile
	local target = (ns.db.profiles and ns.db.profiles[name]) or self._knownProfiles[name]
	if InCombatLockdown() and hasBulkDomains(target) then
		ns.Print(ns.L["Cannot apply a profile with bulk domains during combat; try again after combat"])
		return false, "in-combat-bulk"
	end
	local label = "profile:" .. name

	local prevMute = {}
	for i, id in ipairs(ns.db.profile.mutesound) do prevMute[i] = id end
	local cvarSnap = {}
	local function record(bucket)
		for k in pairs(bucket) do
			if cvarSnap[k] == nil then
				local v = ns.Adapters.cvar:Read(k)
				if v ~= nil then cvarSnap[k] = v end
			end
		end
	end
	record(ns.db.profile.cvar)

	ns.db:SetProfile(name)
	self._knownProfiles[name] = ns.db.profile
	record(ns.db.profile.cvar)
	ns.Engine:LogBulk("cvar", cvarSnap, label)

	if not isContext then
		ns.db.char.baseProfile = name
	end

	local newMuted = {}
	for _, id in ipairs(ns.db.profile.mutesound) do newMuted[id] = true end
	for _, id in ipairs(prevMute) do
		if not newMuted[id] then UnmuteSoundFile(id) end
	end
	ns.Adapters.mutesound:ReplayAll()

	self:ApplyActive(label)
	ns.Print(string.format(ns.L["Switched to profile [%s]%s"], name, reason and ("(" .. reason .. ")") or ""))
	if ns.UI then ns.UI:Refresh() end
end

-- 四轴判定,优先级固定:场景 > 专精 > 分辨率 > 角色基准(AceDB 兜底)
function M:EvaluateContext()
	local cfg = autoCfg()
	local target, axis

	if cfg.scene.enabled then
		local _, itype = IsInInstance()
		local key = (itype == nil or itype == "none") and "world" or itype
		if cfg.scene.map[key] then target, axis = cfg.scene.map[key], ns.L["scene: "] .. key end
	end
	if not target and cfg.spec.enabled and GetSpecialization then
		local specIndex = GetSpecialization()
		local specID = specIndex and GetSpecializationInfo(specIndex)
		if specID and cfg.spec.map[specID] then target, axis = cfg.spec.map[specID], ns.L["spec"] end
	end
	if not target and cfg.resolution.enabled and GetPhysicalScreenSize then
		local w, h = GetPhysicalScreenSize()
		local key = string.format("%dx%d", w, h)
		if cfg.resolution.map[key] then target, axis = cfg.resolution.map[key], ns.L["resolution: "] .. key end
	end

	if target then
		self.contextAxis = axis
		self:Switch(target, ns.L["auto-switch by "] .. axis, true)
	elseif self.contextAxis then
		self.contextAxis = nil
		local base = ns.db.char.baseProfile or "Default"
		if ns.db:GetCurrentProfile() ~= base then
			local mode = cfg.onLeave
			if mode == "keep" then
				ns.Print(string.format(ns.L["Left the auto-switch context, keeping profile [%s] as configured"], self:Current()))
			elseif mode == "restore" or not StaticPopup_Show then
				self:Switch(base, ns.L["context left, falling back"], true)
			else
				-- 默认提示而非静默(Hyperframe 教训)
				StaticPopup_Show("SETTINGSHUB_PROFILE_LEAVE", base, nil, base)
			end
		end
	end
end

-- 导入导出:LibSerialize + LibDeflate + EncodeForPrint(WeakAuras 同款管线)
local MAGIC = "!SH1!"

local function validatePayload(payload)
	if type(payload.data) ~= "table" then return false, ns.L["payload.data must be a table"] end
	if payload.domains ~= nil and type(payload.domains) ~= "table" then
		return false, ns.L["payload.domains must be a table"]
	end

	local cvars = payload.data.cvar
	if cvars ~= nil then
		if type(cvars) ~= "table" then return false, ns.L["payload.data.cvar must be a table"] end
		for k, v in pairs(cvars) do
			if type(k) ~= "string" or k == "" then
				return false, ns.L["payload.data.cvar keys must be non-empty strings"]
			end
			if type(v) ~= "string" and type(v) ~= "number" then
				return false, string.format(ns.L["payload.data.cvar[%s] must be a string or number"], k)
			end
		end
	end

	local console = payload.data.consoleexec
	if console ~= nil then
		if type(console) ~= "table" then return false, ns.L["payload.data.consoleexec must be a table"] end
		for k, v in pairs(console) do
			if type(k) ~= "string" then
				return false, ns.L["payload.data.consoleexec keys must be strings"]
			end
			if type(v) ~= "string" and type(v) ~= "number" then
				return false, string.format(ns.L["payload.data.consoleexec[%s] must be a string or number"], k)
			end
		end
	end

	for _, domain in ipairs(BULK_DOMAINS) do
		if payload.data[domain] ~= nil and type(payload.data[domain]) ~= "table" then
			return false, string.format(ns.L["payload.data.%s must be a table"], domain)
		end
	end
	if payload.data.mutesound ~= nil and type(payload.data.mutesound) ~= "table" then
		return false, ns.L["payload.data.mutesound must be a table"]
	end

	local entries, seen = 0, {}
	local function count(container)
		if type(container) ~= "table" or seen[container] then return true end
		seen[container] = true
		for _, value in pairs(container) do
			entries = entries + 1
			if entries > MAX_ENTRIES then return false end
			if type(value) == "table" and not count(value) then return false end
		end
		return true
	end
	if not count(payload) then
		return false, string.format(ns.L["payload exceeds %d entries"], MAX_ENTRIES)
	end
	return true
end

local function acceptableCvar(key)
	local entry = ns.Enum:Get(key)
	return entry ~= nil and not entry.readonly
end

function M:Export()
	local LibSerialize = LibStub("LibSerialize")
	local LibDeflate = LibStub("LibDeflate")
	local p = ns.db.profile
	local payload = { v = 1, game = (GetBuildInfo()), name = self:Current(), domains = {}, data = {} }
	for d, on in pairs(p.domains) do payload.domains[d] = on and true or false end
	if p.domains.cvar then payload.data.cvar = p.cvar end
	if next(p.consoleexec) then payload.data.consoleexec = p.consoleexec end
	if #p.mutesound > 0 then payload.data.mutesound = p.mutesound end
	for _, d in ipairs(BULK_DOMAINS) do
		if p.domains[d] then payload.data[d] = p[d] or ns.Adapters[d]:Serialize() end
	end
	return MAGIC .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(payload)))
end

function M:Decode(str)
	str = tostring(str or ""):gsub("%s+", "")
	local body = str:match("^!SH1!(.+)$")
	if not body then return nil, string.format(ns.L["missing %s header, not an export string from this addon"], MAGIC) end
	local LibSerialize = LibStub("LibSerialize")
	local LibDeflate = LibStub("LibDeflate")
	local compressed = LibDeflate:DecodeForPrint(body)
	if not compressed then return nil, ns.L["decode failed"] end
	if #compressed > MAX_COMPRESSED then
		return nil, string.format(ns.L["compressed data exceeds %d bytes"], MAX_COMPRESSED)
	end
	local serialized, unprocessedByteCount = LibDeflate:DecompressDeflate(compressed)
	if not serialized then return nil, ns.L["decompress failed"] end
	if unprocessedByteCount ~= nil and unprocessedByteCount ~= 0 then
		return nil, ns.L["compressed data has trailing bytes"]
	end
	if #serialized > MAX_SERIALIZED then
		return nil, string.format(ns.L["decompressed data exceeds %d bytes"], MAX_SERIALIZED)
	end
	local ok, payload = LibSerialize:Deserialize(serialized)
	if not ok or type(payload) ~= "table" or payload.v ~= 1 then return nil, ns.L["deserialize failed or version mismatch"] end
	local valid, err = validatePayload(payload)
	if not valid then return nil, err end
	return payload
end

-- 导入前 diff:cvar 逐项旧值新值;批量域整域替换只报域名
function M:DiffAgainstCurrent(payload)
	local changes, unknown, bulk = {}, 0, {}
	for k, want in pairs(payload.data.cvar or {}) do
		if not acceptableCvar(k) then
			unknown = unknown + 1
		else
			local cur = ns.Adapters.cvar:Read(k)
			if cur ~= tostring(want) then
				changes[#changes + 1] = { key = k, old = cur, new = tostring(want) }
			end
		end
	end
	for k, want in pairs(payload.data.consoleexec or {}) do
		if not ns.Adapters.consoleexec:IsAllowed(k) then
			unknown = unknown + 1
		else
			local cur = ns.db.profile.consoleexec[k]
			if cur ~= tostring(want) then
				changes[#changes + 1] = { key = "console " .. k, old = tostring(cur), new = tostring(want) }
			end
		end
	end
	for _, d in ipairs(BULK_DOMAINS) do
		if payload.data[d] then bulk[#bulk + 1] = d end
	end
	if payload.data.mutesound then bulk[#bulk + 1] = "mutesound" end
	return changes, bulk, unknown
end

function M:ApplyImport(payload)
	if InCombatLockdown() and importHasBulkDomains(payload) then
		ns.Print(ns.L["Cannot import bulk domains during combat; try again after combat"])
		return 0, 0, 0, "in-combat-bulk"
	end
	local applied, failed, skipped = 0, 0, 0
	for k, want in pairs(payload.data.cvar or {}) do
		if not acceptableCvar(k) then
			skipped = skipped + 1
		else
			local r = ns.Engine:Set("cvar", k, want, "import")
			if r == "failed" then failed = failed + 1 else applied = applied + 1 end
		end
	end
	for k, want in pairs(payload.data.consoleexec or {}) do
		if not ns.Adapters.consoleexec:IsAllowed(k) then
			skipped = skipped + 1
		else
			local r = ns.Engine:Set("consoleexec", k, want, "import")
			if r == "failed" then failed = failed + 1 else applied = applied + 1 end
		end
	end
	if payload.data.mutesound then
		ns.Adapters.mutesound:Restore(payload.data.mutesound)
	end
	for _, d in ipairs(BULK_DOMAINS) do
		if payload.data[d] then
			ns.Engine:LogBulk(d, ns.Adapters[d]:Serialize(), "import")
			ns.Adapters[d]:Restore(payload.data[d])
		end
	end
	ns.Print(string.format(ns.L["Import done: %d applied, %d failed, %d skipped (see the Log page for failures)"], applied, failed, skipped))
	if ns.UI then ns.UI:Refresh() end
	return applied, failed, skipped
end
