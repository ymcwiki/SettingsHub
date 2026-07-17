local ADDON, ns = ...

local M = { contextAxis = nil }
ns.Profiles = M

-- 批量域:profile 存 Serialize 快照,应用时整域 Restore(先 LogBulk 记撤销快照)
local BULK_DOMAINS = { "binding", "macro", "editmode", "clickbinding", "tts", "chatwindow" }
M.BULK_DOMAINS = BULK_DOMAINS
M.SCENES = { "party", "raid", "arena", "pvp", "world" }

local function autoCfg()
	return ns.db.global.autoSwitch
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
	local serialized = LibDeflate:DecompressDeflate(compressed)
	if not serialized then return nil, ns.L["decompress failed"] end
	local ok, payload = LibSerialize:Deserialize(serialized)
	if not ok or type(payload) ~= "table" or payload.v ~= 1 then return nil, ns.L["deserialize failed or version mismatch"] end
	return payload
end

-- 导入前 diff:cvar 逐项旧值新值;批量域整域替换只报域名
function M:DiffAgainstCurrent(payload)
	local changes, unknown, bulk = {}, 0, {}
	for k, want in pairs(payload.data.cvar or {}) do
		local cur = ns.Adapters.cvar:Read(k)
		if cur == nil then
			unknown = unknown + 1
		elseif cur ~= tostring(want) then
			changes[#changes + 1] = { key = k, old = cur, new = tostring(want) }
		end
	end
	for k, want in pairs(payload.data.consoleexec or {}) do
		local cur = ns.db.profile.consoleexec[k]
		if cur ~= tostring(want) then
			changes[#changes + 1] = { key = "console " .. k, old = tostring(cur), new = tostring(want) }
		end
	end
	for _, d in ipairs(BULK_DOMAINS) do
		if payload.data[d] then bulk[#bulk + 1] = d end
	end
	if payload.data.mutesound then bulk[#bulk + 1] = "mutesound" end
	return changes, bulk, unknown
end

function M:ApplyImport(payload)
	local applied, failed = 0, 0
	for k, want in pairs(payload.data.cvar or {}) do
		local r = ns.Engine:Set("cvar", k, want, "import")
		if r == "failed" then failed = failed + 1 else applied = applied + 1 end
	end
	for k, want in pairs(payload.data.consoleexec or {}) do
		local r = ns.Engine:Set("consoleexec", k, want, "import")
		if r == "failed" then failed = failed + 1 else applied = applied + 1 end
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
	ns.Print(string.format(ns.L["Import done: %d applied, %d failed (see the Log page for failures)"], applied, failed))
	if ns.UI then ns.UI:Refresh() end
end
