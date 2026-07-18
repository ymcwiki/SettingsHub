local ADDON, ns = ...
local L = ns.L

-- v0.4 发现页:调研点名的「策展式设置推荐引导层」。三段:
-- 建议(声明式条件命中才显示,可不再提示)/ 意图引导(内联真控件)/ 近期补丁新增
local function T(tbl)
	return ns.IsCJK() and tbl.zh or tbl.en
end

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)

	local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -28, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(800, 10)
	scroll:SetScrollChild(content)

	-- 策展控件 id 索引
	local byId = {}
	local function index(controls)
		for _, c in ipairs(controls) do
			byId[c.id] = c
			if c.children then index(c.children) end
		end
	end
	for _, th in ipairs(ns.Data.themes or {}) do index(th.controls) end

	local function controlUsable(c)
		if not c or c.verify then return false end
		if c.domain == "cvar" and c.key and not ns.Enum:Get(c.key) then return false end
		return true
	end

	page.widgets = {}
	-- 布局元素表:{ frame=, height= },OnPageShow 时按可见性从上往下重排
	local elements = {}

	-- 建议区
	local function tipActive(tip)
		if ns.db.global.tipsDismissed[tip.key] then return false end
		local cur = ns.Adapters.cvar:Read(tip.cvar)
		if cur == nil then return false end
		if tip.op == "eq" then
			return cur == tip.value
		end
		local a, b = tonumber(cur), tonumber(tip.value)
		if not (a and b) then return false end
		if tip.op == "lt" then return a < b end
		if tip.op == "gt" then return a > b end
		return false
	end

	local tipsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tipsHeader:SetText("|cffffcc00" .. L["Suggestions based on your current values"] .. "|r")
	elements[#elements + 1] = { frame = tipsHeader, height = 20, isTipHeader = true }

	local tipRows = {}
	for _, tip in ipairs(ns.Data.tips or {}) do
		local row = CreateFrame("Frame", nil, content)
		row:SetSize(780, 10)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("TOPLEFT", 8, -2)
		row.text:SetWidth(540)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(true)
		row.text:SetText(T(tip.text))
		row.applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.applyBtn:SetSize(110, 20)
		row.applyBtn:SetPoint("TOPRIGHT", -110, -2)
		row.applyBtn:SetText(T(tip.action))
		row.applyBtn:SetScript("OnClick", function()
			ns.Engine:Set("cvar", tip.cvar, tip.suggest, "user")
			ns.Print(string.format(L["Suggestion applied: %s = %s"], tip.cvar, tip.suggest))
			page:OnPageShow()
		end)
		row.dismissBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.dismissBtn:SetSize(96, 20)
		row.dismissBtn:SetPoint("LEFT", row.applyBtn, "RIGHT", 6, 0)
		row.dismissBtn:SetText(L["Don't remind me"])
		row.dismissBtn:SetScript("OnClick", function()
			ns.db.global.tipsDismissed[tip.key] = true
			page:OnPageShow()
		end)
		row:SetHeight(math.max(26, row.text:GetStringHeight() + 8))
		row.tip = tip
		tipRows[#tipRows + 1] = row
		elements[#elements + 1] = { frame = row, height = row:GetHeight(), tipRow = row }
	end

	-- 意图引导区
	for _, guide in ipairs(ns.Data.guides or {}) do
		local block = CreateFrame("Frame", nil, content)
		block:SetSize(790, 10)
		local header = block:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", 0, 0)
		header:SetText(T(guide.title))
		local blurb = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		blurb:SetPoint("TOPLEFT", 2, -22)
		blurb:SetWidth(760)
		blurb:SetJustifyH("LEFT")
		blurb:SetWordWrap(true)
		blurb:SetText(T(guide.blurb))
		local y = -26 - blurb:GetStringHeight()
		for _, id in ipairs(guide.items) do
			local c = byId[id]
			if controlUsable(c) then
				local w = ns.Widgets.Create(block, c)
				if w then
					w:SetPoint("TOPLEFT", 10, y)
					w:SetWidth(770)
					y = y - w:GetHeight() - 2
					page.widgets[#page.widgets + 1] = w
				end
			end
		end
		if guide.pack then
			local pb = CreateFrame("Button", nil, block, "UIPanelButtonTemplate")
			pb:SetSize(180, 22)
			pb:SetPoint("TOPLEFT", 10, y - 2)
			pb:SetText(L["Open the matching pack"])
			pb:SetScript("OnClick", function() ns.UI:SelectPage("packs") end)
			y = y - 28
		end
		block:SetHeight(-y + 4)
		elements[#elements + 1] = { frame = block, height = block:GetHeight() }
	end

	-- 近期补丁新增区
	do
		local byPatch = {}
		local function collect(controls)
			for _, c in ipairs(controls) do
				local v = c.version
				if v and v.added and v.added:find("^12%.") then
					byPatch[v.added] = byPatch[v.added] or {}
					table.insert(byPatch[v.added], c)
				end
				if c.children then collect(c.children) end
			end
		end
		for _, th in ipairs(ns.Data.themes or {}) do collect(th.controls) end
		local patches = {}
		for p in pairs(byPatch) do patches[#patches + 1] = p end
		table.sort(patches, function(a, b) return a > b end)
		for _, patch in ipairs(patches) do
			local block = CreateFrame("Frame", nil, content)
			block:SetSize(790, 10)
			local header = block:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			header:SetPoint("TOPLEFT", 0, 0)
			header:SetFormattedText(L["New settings in patch %s"], patch)
			local y = -24
			local unavailable = 0
			for _, c in ipairs(byPatch[patch]) do
				if controlUsable(c) then
					local w = ns.Widgets.Create(block, c)
					if w then
						w:SetPoint("TOPLEFT", 10, y)
						w:SetWidth(770)
						y = y - w:GetHeight() - 2
						page.widgets[#page.widgets + 1] = w
					end
				else
					unavailable = unavailable + 1
				end
			end
			if unavailable > 0 then
				local note = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
				note:SetPoint("TOPLEFT", 10, y - 2)
				note:SetFormattedText(L["%d entries not present on this client version, hidden"], unavailable)
				y = y - 20
			end
			block:SetHeight(-y + 4)
			elements[#elements + 1] = { frame = block, height = block:GetHeight() }
		end
	end

	local function layout()
		local y = -6
		local anyTip = false
		for _, el in ipairs(elements) do
			local show = true
			if el.isTipHeader then
				anyTip = false
				for _, row in ipairs(tipRows) do
					if tipActive(row.tip) then anyTip = true end
				end
				show = anyTip
			elseif el.tipRow then
				show = tipActive(el.tipRow.tip)
			end
			el.frame:SetShown(show)
			if show then
				el.frame:ClearAllPoints()
				el.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
				y = y - el.height - 14
			end
		end
		content:SetHeight(-y + 10)
	end

	function page:OnPageShow()
		layout()
		for _, w in ipairs(self.widgets) do w:Update() end
	end

	ns.Engine:AddListener(function()
		if page:IsShown() then page:OnPageShow() end
	end)

	return page
end

ns.UI:RegisterPage("discover", L["Discover"], build)
