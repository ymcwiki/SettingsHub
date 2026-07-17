local ADDON, ns = ...

local M = { items = nil }
ns.Search = M

local curatedByKey

local function curatedIndex()
	if curatedByKey then return curatedByKey end
	curatedByKey = {}
	local function walk(controls)
		for _, c in ipairs(controls) do
			if c.key and c.domain == "cvar" then curatedByKey[c.key] = c end
			if c.children then walk(c.children) end
		end
	end
	for _, th in ipairs(ns.Data.themes or {}) do
		walk(th.controls)
	end
	return curatedByKey
end

-- 预构建 lowercase blob:名称 + 中英白话描述 + 关键词 + help 原文(调研第八章:线性扫描够用)
-- zh/en/keywords 三路全进索引,任何客户端语言下中英俗名都能命中
function M:Rebuild()
	local cur = curatedIndex()
	local items = {}
	for name, info in pairs(ns.Enum.cache) do
		local c = cur[name]
		local parts = { name:lower() }
		if info.help and info.help ~= "" then parts[#parts + 1] = info.help:lower() end
		if c and c.text then
			if c.text.zh and c.text.zh ~= "" then parts[#parts + 1] = c.text.zh:lower() end
			if c.text.en and c.text.en ~= "" then parts[#parts + 1] = c.text.en:lower() end
			for _, w in ipairs(c.text.keywords or {}) do parts[#parts + 1] = w:lower() end
		end
		items[#items + 1] = { key = name, info = info, control = c, blob = table.concat(parts, " ") }
	end
	table.sort(items, function(a, b) return a.key < b.key end)
	self.items = items
	return items
end

local TAGS = {
	modified = function(it) return it.info.value ~= it.info.default end,
	secure = function(it) return it.info.secure end,
	hidden = function(it) return not (ns.Data.exposed and ns.Data.exposed[it.key]) end,
	new = function(it)
		local v = it.control and it.control.version
		return v and v.added and v.added:find("^12%.1") ~= nil
	end,
}

-- 多词 AND;tag:modified/new/secure/hidden 为谓词;category 为控制台类别过滤
function M:Query(text, category)
	if not self.items then self:Rebuild() end
	local words, preds = {}, {}
	for token in (text or ""):lower():gmatch("%S+") do
		local tag = token:match("^tag:(%w+)$")
		if tag and TAGS[tag] then
			preds[#preds + 1] = TAGS[tag]
		else
			words[#words + 1] = token
		end
	end
	local out = {}
	for _, it in ipairs(self.items) do
		local ok = true
		if category and it.info.category ~= category then ok = false end
		if ok then
			for i = 1, #preds do
				if not preds[i](it) then ok = false break end
			end
		end
		if ok then
			for i = 1, #words do
				if not it.blob:find(words[i], 1, true) then ok = false break end
			end
		end
		if ok then out[#out + 1] = it end
	end
	return out
end

function M:CategoryCounts()
	if not self.items then self:Rebuild() end
	local counts = {}
	for _, it in ipairs(self.items) do
		local c = it.info.category or -1
		counts[c] = (counts[c] or 0) + 1
	end
	return counts
end
