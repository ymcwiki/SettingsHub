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

-- 中文文案转全拼 + 首字母缩写(xingmingban / xmb 都可命中);字表由 gen_pinyin.py 生成
local function pinyinize(zh)
	local map = ns.Data.pinyin
	if not map then return nil end
	local full, initials = {}, {}
	-- CJK 基本区 U+4E00-U+9FFF 的 UTF-8 序列以 0xE4-0xE9 起头
	for ch in zh:gmatch("[\228-\233][\128-\191][\128-\191]") do
		local py = map[ch]
		if py then
			full[#full + 1] = py
			initials[#initials + 1] = py:sub(1, 1)
		end
	end
	if #full == 0 then return nil end
	return table.concat(full) .. " " .. table.concat(initials)
end

-- 预构建 lowercase blob:名称 + 中英白话描述 + 关键词 + 中文拼音 + help 原文(调研第八章:线性扫描够用)
-- zh/en/keywords/pinyin 全进索引,任何客户端语言下中英俗名与拼音都能命中
function M:Rebuild()
	local cur = curatedIndex()
	local items = {}
	for name, info in pairs(ns.Enum.cache) do
		local c = cur[name]
		local dictionary = ns.Data.encyclopedia and ns.Data.encyclopedia[name]
		local parts = { name:lower() }
		if info.help and info.help ~= "" then parts[#parts + 1] = info.help:lower() end
		if c and c.text then
			if c.text.zh and c.text.zh ~= "" then
				parts[#parts + 1] = c.text.zh:lower()
				local py = pinyinize(c.text.zh)
				if py then parts[#parts + 1] = py end
			end
			if c.text.en and c.text.en ~= "" then parts[#parts + 1] = c.text.en:lower() end
			for _, w in ipairs(c.text.keywords or {}) do parts[#parts + 1] = w:lower() end
		end
		if dictionary then
			if dictionary.zh and dictionary.zh ~= "" then parts[#parts + 1] = dictionary.zh:lower() end
			if dictionary.en and dictionary.en ~= "" then parts[#parts + 1] = dictionary.en:lower() end
		end
		items[#items + 1] = { key = name, info = info, control = c, blob = table.concat(parts, " ") }
	end
	table.sort(items, function(a, b) return a.key < b.key end)
	self.items = items
	return items
end

local function isFavorite(it)
	return ns.Favorites:IsFavorite(it.key)
end

local TAGS = {
	favorite = isFavorite,
	fav = isFavorite, -- 短别名,对已经习惯 tag:fav 的用户兼容
	modified = function(it) return it.info.value ~= it.info.default end,
	secure = function(it) return it.info.secure end,
	hidden = function(it) return not (ns.Data.exposed and ns.Data.exposed[it.key]) end,
	new = function(it)
		local v = it.control and it.control.version
		return v and v.added and v.added:find("^12%.1") ~= nil
	end,
}

-- 多词 AND;tag:favorite/modified/new/secure/hidden 为谓词;category 为控制台类别过滤
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
		if category == "favorite" then
			if not ns.Favorites:IsFavorite(it.key) then ok = false end
		elseif category and ns.Data.ClassifyTopic(it.key) ~= category then ok = false end
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

-- 按主题(Data/Topics)分组计数,取代旧的控制台数字类别
function M:CategoryCounts()
	if not self.items then self:Rebuild() end
	local counts = {}
	for _, it in ipairs(self.items) do
		local c = ns.Data.ClassifyTopic(it.key)
		counts[c] = (counts[c] or 0) + 1
	end
	return counts
end
