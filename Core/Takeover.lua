-- 外部接管检测:只读已加载插件状态与静态映射
local ADDON, ns = ...

local M = { activeCache = nil, keyCache = {} }
ns.Takeover = M

local function addonLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(name)
	end
	if IsAddOnLoaded then return IsAddOnLoaded(name) end
	return false
end

local function contains(list, value, insensitive)
	if not list then return false end
	if insensitive then value = value:lower() end
	for _, item in ipairs(list) do
		if (insensitive and item:lower() or item) == value then return true end
	end
	return false
end

function M:ClearCache()
	self.activeCache = nil
	self.keyCache = {}
end

function M:ActiveOwners()
	if self.activeCache then return self.activeCache end
	local hits = {}
	for _, entry in ipairs((ns.Data and ns.Data.takeovers) or {}) do
		for _, addon in ipairs(entry.addons or {}) do
			if addonLoaded(addon) then
				hits[#hits + 1] = { entry = entry, addon = addon }
				break
			end
		end
	end
	self.activeCache = hits
	return hits
end

local function resultFor(hit)
	local text = ns.IsCJK() and hit.entry.text.zh or hit.entry.text.en
	return { addon = hit.addon, text = string.format(text, hit.addon) }
end

function M:ForKey(cvarKey)
	if type(cvarKey) ~= "string" then return nil end
	local key = cvarKey:lower()
	local cached = self.keyCache[key]
	if cached ~= nil then return cached or nil end

	local active = self:ActiveOwners()
	local exactDefined = false
	for _, entry in ipairs((ns.Data and ns.Data.takeovers) or {}) do
		if contains(entry.cvars, key, true) then exactDefined = true break end
	end
	if exactDefined then
		for _, hit in ipairs(active) do
			if contains(hit.entry.cvars, key, true) then
				local result = resultFor(hit)
				self.keyCache[key] = result
				return result
			end
		end
		self.keyCache[key] = false
		return nil
	end

	local topic = ns.Data and ns.Data.ClassifyTopic and ns.Data.ClassifyTopic(cvarKey)
	for _, hit in ipairs(active) do
		if contains(hit.entry.topics, topic, false) then
			local result = resultFor(hit)
			self.keyCache[key] = result
			return result
		end
	end
	self.keyCache[key] = false
	return nil
end
