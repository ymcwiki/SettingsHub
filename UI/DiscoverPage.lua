local ADDON, ns = ...
local L = ns.L
local Style = ns.Style

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
	local patchBlock = CreateFrame("Frame", nil, content, "BackdropTemplate")
	patchBlock:SetSize(790, 10)
	Style.Card(patchBlock)
	patchBlock.header = Style.SectionHeader(patchBlock, L["This patch changed your settings"])
	patchBlock.header:SetPoint("TOPLEFT", Style.CardInset, -Style.CardInset)
	patchBlock.summary = patchBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	patchBlock.summary:SetPoint("TOPLEFT", Style.CardInset, -30)
	patchBlock.summary:SetWidth(744)
	patchBlock.summary:SetJustifyH("LEFT")
	patchBlock.summary:SetWordWrap(true)
	Style.SetColor(patchBlock.summary, "SetTextColor", Style.Colors.PrimaryText)
	patchBlock.changes = patchBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	patchBlock.changes:SetWidth(744)
	patchBlock.changes:SetJustifyH("LEFT")
	patchBlock.changes:SetWordWrap(true)
	Style.SetColor(patchBlock.changes, "SetTextColor", Style.Colors.PrimaryText)
	patchBlock.openBtn = ns.UI.Button(patchBlock, L["Open Snapshots to compare/restore"], 210, 22, true)
	patchBlock.openBtn:SetScript("OnClick", function() ns.UI:SelectPage("snapshot") end)
	patchBlock.dismissBtn = ns.UI.Button(patchBlock, L["Got it"], 90, 22)
	patchBlock.dismissBtn:SetScript("OnClick", function()
		ns.db.global.patchReport.dismissed = true
		page:OnPageShow()
	end)
	elements[#elements + 1] = { frame = patchBlock, height = 10, isPatchReport = true }

	-- 外部接管区:只读提示,加载中的接管插件发生变化时动态刷新
	local takeoverCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
	takeoverCard:SetSize(790, 10)
	Style.Card(takeoverCard)
	local takeoverHeader = Style.SectionHeader(takeoverCard, L["Possible external takeover"])
	takeoverHeader:SetPoint("TOPLEFT", Style.CardInset, -Style.CardInset)
	elements[#elements + 1] = { frame = takeoverCard, height = 10, isTakeoverCard = true }

	local takeoverRows = {}
	for _ = 1, #((ns.Data and ns.Data.takeovers) or {}) do
		local row = takeoverCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row:SetWidth(744)
		row:SetJustifyH("LEFT")
		row:SetWordWrap(true)
		Style.SetColor(row, "SetTextColor", Style.Colors.PrimaryText)
		takeoverRows[#takeoverRows + 1] = row
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

	local tipsCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
	tipsCard:SetSize(790, 10)
	Style.Card(tipsCard)
	local tipsHeader = Style.SectionHeader(tipsCard, L["Suggestions based on your current values"])
	tipsHeader:SetPoint("TOPLEFT", Style.CardInset, -Style.CardInset)
	elements[#elements + 1] = { frame = tipsCard, height = 10, isTipsCard = true }

	local tipRows = {}
	for _, tip in ipairs(ns.Data.tips or {}) do
		local row = CreateFrame("Frame", nil, tipsCard)
		row:SetSize(774, 10)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("TOPLEFT", 8, -2)
		row.text:SetWidth(540)
		row.text:SetJustifyH("LEFT")
		row.text:SetWordWrap(true)
		row.text:SetText(T(tip.text))
		Style.SetColor(row.text, "SetTextColor", Style.Colors.PrimaryText)
		row.applyBtn = ns.UI.Button(row, T(tip.action), 110, 20, true)
		row.applyBtn:SetPoint("TOPRIGHT", -110, -2)
		row.applyBtn:SetScript("OnClick", function()
			ns.Engine:Set("cvar", tip.cvar, tip.suggest, "user")
			ns.Print(string.format(L["Suggestion applied: %s = %s"], tip.cvar, tip.suggest))
			page:OnPageShow()
		end)
		row.dismissBtn = ns.UI.Button(row, L["Don't remind me"], 96, 20)
		row.dismissBtn:SetPoint("LEFT", row.applyBtn, "RIGHT", 6, 0)
		row.dismissBtn:SetScript("OnClick", function()
			ns.db.global.tipsDismissed[tip.key] = true
			page:OnPageShow()
		end)
		row:SetHeight(math.max(26, row.text:GetStringHeight() + 8))
		row.tip = tip
		tipRows[#tipRows + 1] = row
	end

	-- 意图引导区
	for _, guide in ipairs(ns.Data.guides or {}) do
		local block = CreateFrame("Frame", nil, content)
		block:SetSize(790, 10)
		local header = block:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", 0, 0)
		header:SetText(T(guide.title))
		Style.SetColor(header, "SetTextColor", Style.Colors.PrimaryText)
		local blurb = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		blurb:SetPoint("TOPLEFT", 2, -22)
		blurb:SetWidth(760)
		blurb:SetJustifyH("LEFT")
		blurb:SetWordWrap(true)
		blurb:SetText(T(guide.blurb))
		Style.SetColor(blurb, "SetTextColor", Style.Colors.SecondaryText)
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
			local pb = ns.UI.Button(block, L["Open the matching pack"], 180, 22)
			pb:SetPoint("TOPLEFT", 10, y - 2)
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
			Style.SetColor(header, "SetTextColor", Style.Colors.PrimaryText)
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
				+ patchBlock.changes:GetStringHeight() + 38 + Style.CardInset * 2
			patchBlock:SetHeight(height)
			for _, el in ipairs(elements) do
				if el.isPatchReport then el.height = height break end
			end
		end
		for i, row in ipairs(takeoverRows) do
			local hit = owners[i]
			row:SetShown(hit ~= nil)
			if hit then
				local text = ns.IsCJK() and hit.entry.text.zh or hit.entry.text.en
				row:SetText(string.format(L["Detected %s: %s"], hit.addon, string.format(text, hit.addon)))
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", takeoverCard, "TOPLEFT", Style.CardInset, -30 - (i - 1) * 22)
			end
		end
		local takeoverHeight = 30 + #owners * 22 + Style.CardInset
		takeoverCard:SetHeight(takeoverHeight)

		local tipY = -30
		for _, row in ipairs(tipRows) do
			local show = tipActive(row.tip)
			row:SetShown(show)
			if show then
				anyTip = true
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", tipsCard, "TOPLEFT", Style.CardInset, tipY)
				tipY = tipY - row:GetHeight()
			end
		end
		local tipsHeight = -tipY + Style.CardInset
		tipsCard:SetHeight(tipsHeight)
		for _, el in ipairs(elements) do
			local show = true
			if el.isPatchReport then
				show = reportVisible
			elseif el.isTakeoverCard then
				show = #owners > 0
				el.height = takeoverHeight
			elseif el.isTipsCard then
				show = anyTip
				el.height = tipsHeight
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
