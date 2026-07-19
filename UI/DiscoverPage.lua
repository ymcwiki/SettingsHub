local ADDON, ns = ...
local L = ns.L

-- 发现页:外部接管(只读)/ 建议(条件命中才显示)/ 意图引导(内联真控件)/ 近期补丁新增
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

	-- 补丁漂移报告:只展示 PatchWatch 已保存的 diff,恢复仍由用户进入快照页主动操作
	local patchBlock = CreateFrame("Frame", nil, content)
	patchBlock:SetSize(790, 10)
	patchBlock.header = patchBlock:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	patchBlock.header:SetPoint("TOPLEFT", 0, 0)
	patchBlock.header:SetText("|cffffcc00" .. L["This patch changed your settings"] .. "|r")
	patchBlock.summary = patchBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	patchBlock.summary:SetPoint("TOPLEFT", 2, -24)
	patchBlock.summary:SetWidth(760)
	patchBlock.summary:SetJustifyH("LEFT")
	patchBlock.summary:SetWordWrap(true)
	patchBlock.changes = patchBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	patchBlock.changes:SetWidth(760)
	patchBlock.changes:SetJustifyH("LEFT")
	patchBlock.changes:SetWordWrap(true)
	patchBlock.openBtn = CreateFrame("Button", nil, patchBlock, "UIPanelButtonTemplate")
	patchBlock.openBtn:SetSize(210, 22)
	patchBlock.openBtn:SetText(L["Open Snapshots to compare/restore"])
	patchBlock.openBtn:SetScript("OnClick", function() ns.UI:SelectPage("snapshot") end)
	patchBlock.dismissBtn = CreateFrame("Button", nil, patchBlock, "UIPanelButtonTemplate")
	patchBlock.dismissBtn:SetSize(90, 22)
	patchBlock.dismissBtn:SetText(L["Got it"])
	patchBlock.dismissBtn:SetScript("OnClick", function()
		ns.db.global.patchReport.dismissed = true
		page:OnPageShow()
	end)
	elements[#elements + 1] = { frame = patchBlock, height = 10, isPatchReport = true }

	-- 外部接管区:只读提示,加载中的接管插件发生变化时动态刷新
	local takeoverHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	takeoverHeader:SetText("|cffff8800" .. L["Possible external takeover"] .. "|r")
	elements[#elements + 1] = { frame = takeoverHeader, height = 20, isTakeoverHeader = true }

	local takeoverRows = {}
	for _ = 1, #((ns.Data and ns.Data.takeovers) or {}) do
		local row = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row:SetWidth(760)
		row:SetJustifyH("LEFT")
		row:SetWordWrap(true)
		takeoverRows[#takeoverRows + 1] = row
		elements[#elements + 1] = { frame = row, height = 22, takeoverIndex = #takeoverRows }
	end

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
		local owners = ns.Takeover and ns.Takeover:ActiveOwners() or {}
		local report = ns.db.global.patchReport
		local reportVisible = report and not report.dismissed
			and (#report.changed + #report.added + #report.removed > 0)
		if reportVisible then
			patchBlock.summary:SetFormattedText(
				L["Patch %s → %s: %d values changed, %d added, %d removed"],
				tostring(report.fromVersion), tostring(report.toVersion),
				#report.changed, #report.added, #report.removed)
			local lines = {}
			for i = 1, math.min(6, #report.changed) do
				local change = report.changed[i]
				lines[#lines + 1] = change.key .. ": " .. tostring(change.from) .. " → " .. tostring(change.to)
			end
			patchBlock.changes:ClearAllPoints()
			patchBlock.changes:SetPoint("TOPLEFT", patchBlock.summary, "BOTTOMLEFT", 0, -6)
			patchBlock.changes:SetText(table.concat(lines, "\n"))
			patchBlock.openBtn:ClearAllPoints()
			patchBlock.openBtn:SetPoint("TOPLEFT", patchBlock.changes, "BOTTOMLEFT", 0, -8)
			patchBlock.dismissBtn:ClearAllPoints()
			patchBlock.dismissBtn:SetPoint("LEFT", patchBlock.openBtn, "RIGHT", 8, 0)
			local height = 24 + patchBlock.summary:GetStringHeight()
				+ patchBlock.changes:GetStringHeight() + 38
			patchBlock:SetHeight(height)
			for _, el in ipairs(elements) do
				if el.isPatchReport then el.height = height break end
			end
		end
		for i, row in ipairs(takeoverRows) do
			local hit = owners[i]
			if hit then
				local text = ns.IsCJK() and hit.entry.text.zh or hit.entry.text.en
				row:SetText(string.format(L["Detected %s: %s"], hit.addon, string.format(text, hit.addon)))
			end
		end
		for _, el in ipairs(elements) do
			local show = true
			if el.isPatchReport then
				show = reportVisible
			elseif el.isTakeoverHeader then
				show = #owners > 0
			elseif el.takeoverIndex then
				show = owners[el.takeoverIndex] ~= nil
			elseif el.isTipHeader then
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
