local ADDON, ns = ...
local L = ns.L
local G = ns.Guard
local Style = ns.Style
local C = Style.Colors
local M = Style.Markup
local COL = Style.ListColumns

ns.UI = ns.UI or {}

StaticPopupDialogs["SETTINGSHUB_COPY"] = {
	text = L["Ctrl+C to copy:"],
	button1 = CLOSE,
	hasEditBox = true, editBoxWidth = Style.CopyEditWidth,
	OnShow = G(function(self, data)
		local eb = ns.UI.PopupEditBox(self)
		if not eb then return end
		eb:SetText(data or "")
		eb:HighlightText()
		eb:SetFocus()
	end),
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function color(target, method, value)
	target[method](target, value[1], value[2], value[3], value[4])
end

local function scopeBadge(scope)
	if scope == "account" then return M.Account .. L["Account"] .. M.Close end
	if scope == "character" then return M.Character .. L["Character"] .. M.Close end
	return M.Machine .. L["Machine"] .. M.Close
end

local function toggleFavorite(key)
	ns.Favorites:Toggle(key)
	-- 纯 UI 状态，不走写管线；刷新让收藏页取消后立即移出。
	ns.UI:Refresh()
end

local function flagText(it)
	local parts = {}
	if it.info.secure then parts[#parts + 1] = M.Secure .. L["Secure"] .. M.Close end
	if it.info.readonly then parts[#parts + 1] = M.Disabled .. L["Read-only"] .. M.Close end
	if it.info.locked then parts[#parts + 1] = M.Disabled .. L["Locked"] .. M.Close end
	if it.control and it.control.requiresReload then parts[#parts + 1] = M.Reload .. L["Reload"] .. M.Close end
	if it.control and it.control.requiresRestart then parts[#parts + 1] = M.Restart .. L["Restart"] .. M.Close end
	if ns.Takeover and ns.Takeover:ForKey(it.key) then parts[#parts + 1] = M.Warning .. "⚠" .. M.Close end
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
		editor:SetSize(Style.EditorWidth, Style.EditorHeight)
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

local function addLine(text, value, wrap)
	GameTooltip:AddLine(text, value[1], value[2], value[3], wrap)
end

local function addDouble(left, right, leftColor, rightColor)
	GameTooltip:AddDoubleLine(left, right,
		leftColor[1], leftColor[2], leftColor[3], rightColor[1], rightColor[2], rightColor[3])
end

local function rowTooltip(row, it)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	addLine(it.key, C.TooltipTitle)
	local desc = it.control and ns.ControlText(it.control) or ""
	local dictionary = ns.Data.encyclopedia and ns.Data.encyclopedia[it.key]
	if desc ~= "" then
		addLine(desc, C.TooltipDescription, true)
	elseif dictionary then
		local locale = GetLocale()
		local value = (locale == "zhCN" or locale == "zhTW") and dictionary.zh or dictionary.en
		if value and value ~= "" then addLine(value, C.TooltipDescription, true) end
	end
	if it.info.help ~= "" then addLine(it.info.help, C.TooltipMuted, true) end
	addDouble(L["Current"], tostring(it.info.value), C.TooltipLabel, C.TooltipValue)
	addDouble(L["Default"], tostring(it.info.default), C.TooltipLabel, C.TooltipValue)
	addDouble(L["Scope"], scopeBadge(it.info.scope), C.TooltipLabel, C.TooltipValue)
	local blame = ns.Blame:Get(it.key)
	if blame then
		addDouble(L["Last write"], string.format("%s(%s)", blame.by, date("%m-%d %H:%M", blame.t)),
			C.TooltipLabel, C.TooltipAccent)
	end
	local version = it.control and it.control.version
	if version and version.added then
		addDouble(L["Added in"], version.added, C.TooltipLabel, C.TooltipVersion)
	elseif dictionary and dictionary.ver then
		addDouble(L["Added in"], dictionary.ver, C.TooltipLabel, C.TooltipVersion)
	end
	if desc ~= "" then
		addLine(L["Verified by hand"], C.TooltipVerified, true)
	elseif dictionary and dictionary.src == "f" then
		addLine(L["Inferred from cvar naming and family patterns, not individually verified"],
			C.TooltipUnverified, true)
	elseif dictionary then
		addLine(L["Dictionary: from community docs (CC BY-SA), not individually verified in-game"],
			C.TooltipUnverified, true)
	else
		addLine(L["Internal cvar, purpose undocumented by Blizzard"], C.TooltipUnverified, true)
	end
	local takeover = ns.Takeover and ns.Takeover:ForKey(it.key)
	if takeover then
		addLine(M.Warning .. "⚠ " .. takeover.text .. M.Close, C.TooltipWarning, true)
	end
	GameTooltip:Show()
end

local function buildRow(row)
	row.built = true
	Style.ListRow(row, false)
	row:RegisterForClicks("RightButtonUp")
	row.star = CreateFrame("Button", nil, row)
	row.star:SetSize(Style.FavoriteButtonSize, Style.FavoriteButtonSize)
	row.star:SetPoint("LEFT", COL.name + 2, 0)
	row.star.text = row.star:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	row.star.text:SetPoint("CENTER")
	row.star:SetScript("OnClick", G(function()
		if row.it then toggleFavorite(row.it.key) end
	end))
	row.star:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		addLine(L["Toggle favorite"], C.TooltipTitle)
		addLine(L["Favorites gather in the Favorites tab and the tag:favorite filter"],
			C.TooltipLabel, true)
		GameTooltip:Show()
	end)
	row.star:SetScript("OnLeave", function() GameTooltip:Hide() end)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", COL.name + Style.ListNameInset, 0)
	row.name:SetWidth(COL.value - COL.name - Style.ListNameInset - Style.ListColumnGap)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	color(row.name, "SetTextColor", C.PrimaryText)

	row.valueBtn = CreateFrame("Button", nil, row)
	row.valueBtn:SetPoint("LEFT", COL.value, 0)
	row.valueBtn:SetSize(COL.default - COL.value - Style.ListColumnGap, Style.ListRowHeight)
	row.valueText = row.valueBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.valueText:SetPoint("LEFT")
	row.valueText:SetJustifyH("LEFT")
	row.valueBtn:SetScript("OnClick", G(function()
		if row.it then openEditor(row.valueBtn, row.it) end
	end))

	row.default = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	row.default:SetPoint("LEFT", COL.default, 0)
	row.default:SetWidth(COL.scope - COL.default - Style.ListColumnGap)
	row.default:SetJustifyH("LEFT")
	row.default:SetWordWrap(false)
	color(row.default, "SetTextColor", C.SecondaryText)

	row.scope = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.scope:SetPoint("LEFT", COL.scope, 0)

	row.flags = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.flags:SetPoint("LEFT", COL.flags, 0)
	row.flags:SetJustifyH("LEFT")

	local highlight = Style.Fill(row, "HIGHLIGHT", C.RowHover)
	highlight:SetAllPoints()

	row:SetScript("OnClick", G(function(self, button)
		if button == "RightButton" and self.it then showRowMenu(self, self.it) end
	end))
	row:SetScript("OnEnter", G(function(self)
		if self.it then rowTooltip(self, self.it) end
	end))
	row:SetScript("OnLeave", G(function() GameTooltip:Hide() end))
end

local function updateRow(row, it, even)
	row.it = it
	Style.ListRow(row, even)
	local favorite = ns.Favorites:IsFavorite(it.key)
	row.star.text:SetText(favorite and "★" or "☆")
	color(row.star.text, "SetTextColor", favorite and C.Favorite or C.Unfavorite)
	local curated = it.control and ns.ControlText(it.control) ~= ""
	row.name:SetText((curated and (M.Curated .. "•" .. M.Close .. " ") or "") .. it.key)
	local modified = it.info.value ~= it.info.default
	row.valueText:SetText(tostring(it.info.value))
	color(row.valueText, "SetTextColor", modified and C.Modified or C.NormalValue)
	row.default:SetText(tostring(it.info.default))
	row.scope:SetText(scopeBadge(it.info.scope))
	row.flags:SetText(flagText(it))
	local locked = it.info.secure and ns.UI.combatLocked
	row:SetAlpha(locked and 0.4 or 1)
	row.valueBtn:SetEnabled(not locked and not it.info.readonly)
end

function ns.UI.CreateCvarList(parent, getFilter)
	local list = CreateFrame("Frame", nil, parent)
	list.rowParity = {}

	local header = CreateFrame("Frame", nil, list)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", -Style.ListScrollBarReserve, 0)
	header:SetHeight(Style.ListHeaderHeight)
	local function headCol(text, x)
		local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("LEFT", x, 0)
		fs:SetText(text)
		color(fs, "SetTextColor", C.SecondaryText)
	end
	headCol(L["Name"], COL.name + Style.ListNameInset)
	headCol(L["Current (click to edit)"], COL.value)
	headCol(L["Default"], COL.default)
	headCol(L["Scope"], COL.scope)
	headCol(L["Flags"], COL.flags)
	local headerLine = Style.Fill(header, "ARTWORK", C.Separator)
	headerLine:SetPoint("BOTTOMLEFT")
	headerLine:SetPoint("BOTTOMRIGHT")
	headerLine:SetHeight(Style.SeparatorHeight)

	list.scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
	list.scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	list.scrollBox:SetPoint("BOTTOMRIGHT", -Style.ListScrollBarReserve, 0)
	list.scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
	list.scrollBar:SetPoint("TOPLEFT", list.scrollBox, "TOPRIGHT", Style.ListScrollBarGap, 0)
	list.scrollBar:SetPoint("BOTTOMLEFT", list.scrollBox, "BOTTOMRIGHT", Style.ListScrollBarGap, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(Style.ListRowHeight)
	view:SetElementInitializer("Button", function(row, it)
		if not row.built then buildRow(row) end
		updateRow(row, it, list.rowParity[it])
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(list.scrollBox, list.scrollBar, view)

	function list:Refresh()
		local searchText, category = getFilter()
		local results = ns.Search:Query(searchText or "", category)
		self.resultCount = #results
		wipe(self.rowParity)
		for i, it in ipairs(results) do self.rowParity[it] = i % 2 == 0 end
		self.scrollBox:SetDataProvider(CreateDataProvider(results), ScrollBoxConstants.RetainScrollPosition)
		if self.OnResultsChanged then self:OnResultsChanged(self.resultCount) end
	end

	function list:UpdateRows()
		self.scrollBox:ForEachFrame(function(row)
			if row.it then updateRow(row, row.it, self.rowParity[row.it]) end
		end)
	end

	ns.Engine:AddListener(function()
		if list:IsShown() then list:UpdateRows() end
	end)

	return list
end
