local ADDON, ns = ...
local L = ns.L
local G = ns.Guard

local ROW_H = 24
local CAT_W = 110

-- ConsoleGetAllCommands 的 category 数字段位(census 口径:4=Game 最多,1=Graphics,5=Default,0=Debug,7=Sound)
local CATEGORY_NAMES = {
	[0] = "Debug", [1] = "Graphics", [2] = "Console", [3] = "Combat", [4] = "Game",
	[5] = "Default", [6] = "Net", [7] = "Sound", [8] = "GM", [10] = "Bnet",
}

local COL = { name = 0, value = 320, default = 445, scope = 570, flags = 630 }

StaticPopupDialogs["SETTINGSHUB_COPY"] = {
	text = L["Ctrl+C to copy:"],
	button1 = CLOSE,
	hasEditBox = true, editBoxWidth = 320,
	OnShow = function(self, data)
		self.editBox:SetText(data or "")
		self.editBox:HighlightText()
		self.editBox:SetFocus()
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function scopeBadge(scope)
	if scope == "account" then return "|cff4da6ff" .. L["Account"] .. "|r" end
	if scope == "character" then return "|cff66cc66" .. L["Character"] .. "|r" end
	return "|cff999999" .. L["Machine"] .. "|r"
end

local function toggleFavorite(key)
	ns.Favorites:Toggle(key)
	-- 纯 UI 状态,不走写管线;刷新让星标分类计数与当前列表(星标分类下取消即移出)同步
	ns.UI:Refresh()
end

local function flagText(it)
	local parts = {}
	if it.info.secure then parts[#parts + 1] = "|cffff5555" .. L["Secure"] .. "|r" end
	if it.info.readonly then parts[#parts + 1] = "|cff888888" .. L["Read-only"] .. "|r" end
	if it.info.locked then parts[#parts + 1] = "|cff888888" .. L["Locked"] .. "|r" end
	if it.control and it.control.requiresReload then parts[#parts + 1] = "|cffffcc00" .. L["Reload"] .. "|r" end
	if it.control and it.control.requiresRestart then parts[#parts + 1] = "|cffff8800" .. L["Restart"] .. "|r" end
	return table.concat(parts, " ")
end

local editor

local function commitEdit()
	local it = editor.it
	editor:Hide()
	if not it then return end
	local r, err = ns.Engine:Set("cvar", it.key, editor:GetText(), "user")
	if r == "failed" then
		ns.Print(string.format(L["%s write failed (%s): may be read-only or an invalid value"], it.key, tostring(err)))
	elseif r == "queued" then
		ns.Print(string.format(L["%s queued during combat, applies when combat ends"], it.key))
	end
	ns.UI:Refresh()
end

local function openEditor(anchor, it)
	if it.info.secure and ns.UI.combatLocked then
		ns.Print(L["Secure values are locked in combat, try again after combat"])
		return
	end
	if not editor then
		editor = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
		editor:SetSize(110, 20)
		editor:SetAutoFocus(true)
		editor:SetScript("OnEnterPressed", G(commitEdit))
		editor:SetScript("OnEscapePressed", function(self) self.it = nil; self:Hide() end)
		editor:SetScript("OnEditFocusLost", function(self) self.it = nil; self:Hide() end)
	end
	editor.it = it
	editor:SetParent(anchor)
	editor:ClearAllPoints()
	editor:SetPoint("LEFT", anchor, "LEFT", 0, 0)
	editor:SetText(it.info.value or "")
	editor:HighlightText()
	editor:Show()
	editor:SetFocus()
end

local function showRowMenu(row, it)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		StaticPopup_Show("SETTINGSHUB_COPY", nil, nil, it.key)
		return
	end
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(it.key)
		root:CreateButton(string.format(L["Reset to default (%s)"], tostring(it.info.default)), function()
			ns.Engine:ResetToDefault("cvar", it.key)
			ns.UI:Refresh()
		end)
		root:CreateButton(L["Copy name"], function()
			StaticPopup_Show("SETTINGSHUB_COPY", nil, nil, it.key)
		end)
		root:CreateButton(L["Copy set command"], function()
			StaticPopup_Show("SETTINGSHUB_COPY", nil, nil,
				string.format("/console %s %s", it.key, tostring(it.info.value)))
		end)
		root:CreateButton(ns.Favorites:IsFavorite(it.key) and L["Remove from favorites"] or L["Add to favorites"],
			function() toggleFavorite(it.key) end)
		if ns.Profiles then
			root:CreateButton(L["Pin current value to active profile"], function()
				ns.Profiles:Pin("cvar", it.key)
			end)
		end
	end)
end

local function rowTooltip(row, it)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(it.key, 1, 1, 1)
	local desc = it.control and ns.ControlText(it.control) or ""
	if desc ~= "" then
		GameTooltip:AddLine(desc, 0.9, 0.9, 0.6, true)
	end
	if it.info.help ~= "" then
		GameTooltip:AddLine(it.info.help, 0.6, 0.6, 0.6, true)
	end
	GameTooltip:AddDoubleLine(L["Current"], tostring(it.info.value), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine(L["Default"], tostring(it.info.default), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine(L["Scope"], scopeBadge(it.info.scope), 0.8, 0.8, 0.8)
	local blame = ns.Blame:Get(it.key)
	if blame then
		GameTooltip:AddDoubleLine(L["Last write"], string.format("%s(%s)", blame.by, date("%m-%d %H:%M", blame.t)),
			0.8, 0.8, 0.8, 1, 0.7, 0.3)
	end
	local v = it.control and it.control.version
	if v and v.added then
		GameTooltip:AddDoubleLine(L["Added in"], v.added, 0.8, 0.8, 0.8, 0.6, 0.9, 1)
	end
	GameTooltip:Show()
end

local function buildRow(row)
	row.built = true
	row:RegisterForClicks("RightButtonUp")
	row.star = CreateFrame("Button", nil, row)
	row.star:SetSize(18, 18)
	row.star:SetPoint("LEFT", COL.name + 2, 0)
	row.star.text = row.star:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	row.star.text:SetPoint("CENTER")
	row.star:SetScript("OnClick", G(function(self)
		if row.it then toggleFavorite(row.it.key) end
	end))
	row.star:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Toggle favorite"], 1, 1, 1)
		GameTooltip:AddLine(L["Favorites gather in the star category on the left and the tag:favorite filter"],
			0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	row.star:SetScript("OnLeave", function() GameTooltip:Hide() end)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", COL.name + 22, 0)
	row.name:SetWidth(COL.value - COL.name - 28)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.valueBtn = CreateFrame("Button", nil, row)
	row.valueBtn:SetPoint("LEFT", COL.value, 0)
	row.valueBtn:SetSize(COL.default - COL.value - 6, ROW_H)
	row.valueText = row.valueBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.valueText:SetPoint("LEFT")
	row.valueText:SetJustifyH("LEFT")
	row.valueBtn:SetScript("OnClick", G(function() openEditor(row.valueBtn, row.it) end))

	row.default = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	row.default:SetPoint("LEFT", COL.default, 0)
	row.default:SetWidth(COL.scope - COL.default - 6)
	row.default:SetJustifyH("LEFT")
	row.default:SetWordWrap(false)

	row.scope = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.scope:SetPoint("LEFT", COL.scope, 0)

	row.flags = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.flags:SetPoint("LEFT", COL.flags, 0)
	row.flags:SetJustifyH("LEFT")

	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.06)

	row:SetScript("OnClick", G(function(self, button)
		if button == "RightButton" then showRowMenu(self, self.it) end
	end))
	row:SetScript("OnEnter", function(self) rowTooltip(self, self.it) end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function updateRow(row, it)
	row.it = it
	local fav = ns.Favorites:IsFavorite(it.key)
	row.star.text:SetText(fav and "★" or "☆")
	row.star.text:SetTextColor(fav and 1 or 0.55, fav and 0.82 or 0.55, fav and 0.15 or 0.55)
	local curated = it.control and ns.ControlText(it.control) ~= ""
	row.name:SetText((curated and "|cffffcc00•|r " or "") .. it.key)
	local modified = it.info.value ~= it.info.default
	row.valueText:SetText(tostring(it.info.value))
	if modified then
		row.valueText:SetTextColor(1, 0.6, 0.1)
	else
		row.valueText:SetTextColor(1, 1, 1)
	end
	row.default:SetText(tostring(it.info.default))
	row.scope:SetText(scopeBadge(it.info.scope))
	row.flags:SetText(flagText(it))
	local locked = it.info.secure and ns.UI.combatLocked
	row:SetAlpha(locked and 0.4 or 1)
	row.valueBtn:SetEnabled(not locked and not it.info.readonly)
end

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)

	page.catFrame = CreateFrame("Frame", nil, page)
	page.catFrame:SetPoint("TOPLEFT", 0, -26)
	page.catFrame:SetPoint("BOTTOMLEFT")
	page.catFrame:SetWidth(CAT_W)
	page.catButtons = {}

	page.count = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.count:SetPoint("TOPLEFT", 0, -4)

	local header = CreateFrame("Frame", nil, page)
	header:SetPoint("TOPLEFT", CAT_W + 6, -26)
	header:SetPoint("TOPRIGHT", -22, -26)
	header:SetHeight(18)
	local function headCol(text, x)
		local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("LEFT", x, 0)
		fs:SetText(text)
	end
	headCol(L["Name"], COL.name + 22)
	headCol(L["Current (click to edit)"], COL.value)
	headCol(L["Default"], COL.default)
	headCol(L["Scope"], COL.scope)
	headCol(L["Flags"], COL.flags)

	page.scrollBox = CreateFrame("Frame", nil, page, "WowScrollBoxList")
	page.scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	page.scrollBox:SetPoint("BOTTOMRIGHT", -22, 2)
	page.scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
	page.scrollBar:SetPoint("TOPLEFT", page.scrollBox, "TOPRIGHT", 4, 0)
	page.scrollBar:SetPoint("BOTTOMLEFT", page.scrollBox, "BOTTOMRIGHT", 4, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_H)
	view:SetElementInitializer("Button", function(row, it)
		if not row.built then buildRow(row) end
		updateRow(row, it)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(page.scrollBox, page.scrollBar, view)

	function page:RunQuery()
		local results = ns.Search:Query(ns.UI:GetSearchText(), self.category)
		self.scrollBox:SetDataProvider(CreateDataProvider(results), ScrollBoxConstants.RetainScrollPosition)
		self.count:SetFormattedText(L["%d / %d entries"], #results, ns.Enum.count)
	end

	function page:RebuildCategories()
		local counts = ns.Search:CategoryCounts()
		local sorted = {}
		for id, n in pairs(counts) do sorted[#sorted + 1] = { id = id, n = n } end
		table.sort(sorted, function(a, b) return a.n > b.n end)
		table.insert(sorted, 1, { id = nil, n = ns.Enum.count, all = true })
		local favN = 0
		for _, key in ipairs(ns.Favorites:List()) do
			-- 只计本客户端存在的项;别的客户端收藏的键留在表里不显示也不丢
			if ns.Enum.cache[key] then favN = favN + 1 end
		end
		table.insert(sorted, 2, { id = "favorite", n = favN, favorite = true })
		for _, btn in ipairs(self.catButtons) do btn:Hide() end
		local y = 0
		for i, c in ipairs(sorted) do
			local btn = self.catButtons[i]
			if not btn then
				btn = CreateFrame("Button", nil, self.catFrame)
				btn:SetSize(CAT_W, 20)
				btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				btn.text:SetPoint("LEFT", 4, 0)
				local hl = btn:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints()
				hl:SetColorTexture(1, 1, 1, 0.08)
				self.catButtons[i] = btn
			end
			btn:SetPoint("TOPLEFT", 0, y)
			local label = c.all and L["All"]
				or c.favorite and ("★ " .. L["Favorites"])
				or (CATEGORY_NAMES[c.id] or (L["Category"] .. " " .. tostring(c.id)))
			local sel = (self.category == c.id) or (c.all and self.category == nil)
			btn.text:SetText(string.format("%s%s (%d)|r", sel and "|cffffcc00" or "|cffcccccc", label, c.n))
			btn:SetScript("OnClick", function()
				self.category = c.id
				self:RebuildCategories()
				self:RunQuery()
			end)
			btn:Show()
			y = y - 21
		end
	end

	function page:OnSearch()
		self:RunQuery()
	end

	function page:OnPageShow()
		self:RebuildCategories()
		self:RunQuery()
	end

	ns.Engine:AddListener(function()
		if page:IsShown() then
			page.scrollBox:ForEachFrame(function(row)
				if row.it then updateRow(row, row.it) end
			end)
		end
	end)

	return page
end

ns.UI:RegisterPage("browser", L["Browser"], build)
