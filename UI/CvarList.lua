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

local function trimNum(v)
	local s = tostring(v or "")
	if s:find(".", 1, true) then s = s:gsub("0+$", ""):gsub("%.$", "") end
	return s
end

local function valuesEqual(a, b)
	local na, nb = tonumber(a), tonumber(b)
	if na ~= nil and nb ~= nil then return na == nb end
	return tostring(a or "") == tostring(b or "")
end

local function writeCvar(it, v)
	if not it or not it.info or tostring(it.info.value or "") == tostring(v or "") then
		return "unchanged"
	end
	local r, err = ns.Engine:Set("cvar", it.key, v, "user")
	if r == "failed" then
		ns.Print(string.format(L["%s write failed (%s): may be read-only or an invalid value"],
			it.key, tostring(err)))
	elseif r == "queued" then
		ns.Print(string.format(L["%s queued during combat, applies when combat ends"], it.key))
	end
	ns.UI:Refresh()
	return r
end

local function toggleFavorite(key)
	ns.Favorites:Toggle(key)
	-- 纯 UI 状态，不走写管线；刷新让收藏页取消后立即移出。
	ns.UI:Refresh()
end

local function flagText(it, control)
	local parts = {}
	if it.info.secure then parts[#parts + 1] = M.Secure .. L["Secure"] .. M.Close end
	if it.info.readonly then parts[#parts + 1] = M.Disabled .. L["Read-only"] .. M.Close end
	if it.info.locked then parts[#parts + 1] = M.Disabled .. L["Locked"] .. M.Close end
	if control and control.requiresReload then parts[#parts + 1] = M.Reload .. L["Reload"] .. M.Close end
	if control and control.requiresRestart then parts[#parts + 1] = M.Restart .. L["Restart"] .. M.Close end
	local takeover = ns.Takeover and ns.Takeover:ForKey(it.key)
	if takeover then
		parts[#parts + 1] = M.Warning
			.. string.format(L["⚠ Taken over by %s"], takeover.addon) .. M.Close
	end
	return table.concat(parts, " ")
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

local function attachRowTooltip(frame, row)
	frame:SetScript("OnEnter", G(function()
		if row.it and not row.it.internalHeader then rowTooltip(row, row.it) end
	end))
	frame:SetScript("OnLeave", G(function() GameTooltip:Hide() end))
end

local function restoreEdit(row, edit, numeric)
	if row.it and row.it.info then
		local value = row.it.info.value
		edit:SetText(numeric and trimNum(value) or tostring(value or ""))
	end
	edit:ClearFocus()
end

local function buildToggle(row)
	local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	check:SetPoint("LEFT", COL.control, 0)
	check:SetScript("OnClick", G(function(self)
		if row.kind == "toggle" and row.it then
			writeCvar(row.it, self:GetChecked() and "1" or "0")
		end
	end))
	attachRowTooltip(check, row)
	row.controls.toggle = check
	return check
end

local function buildSlider(row)
	local control = CreateFrame("Frame", nil, row)
	control:SetSize(Style.ListControlWidth, Style.ListRowHeightTall)
	control:SetPoint("LEFT", COL.control, 0)

	control.slider = CreateFrame("Slider", nil, control)
	control.slider:SetOrientation("HORIZONTAL")
	control.slider:SetSize(164, 16)
	control.slider:SetPoint("LEFT", 0, 0)
	control.slider:SetObeyStepOnDrag(true)
	control.slider:EnableMouse(true)
	local track = Style.Fill(control.slider, "BACKGROUND", C.SecondaryText)
	track:SetPoint("LEFT", 0, 0)
	track:SetPoint("RIGHT", 0, 0)
	track:SetHeight(4)
	control.slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local thumb = control.slider:GetThumbTexture()
	if thumb then thumb:SetSize(24, 24) end

	control.edit = CreateFrame("EditBox", nil, control, "InputBoxTemplate")
	control.edit:SetSize(56, 20)
	control.edit:SetPoint("LEFT", control.slider, "RIGHT", 12, 0)
	control.edit:SetAutoFocus(false)
	control.edit:SetScript("OnEnterPressed", G(function(self)
		if row.kind == "slider" and row.it and not valuesEqual(row.it.info.value, self:GetText()) then
			writeCvar(row.it, self:GetText())
		end
		self:ClearFocus()
	end))
	control.edit:SetScript("OnEscapePressed", function(self) restoreEdit(row, self, true) end)

	control.slider:SetScript("OnValueChanged", function(_, value, userInput)
		if userInput and row.kind == "slider" then control.edit:SetText(trimNum(value)) end
	end)
	control.slider:SetScript("OnMouseUp", G(function(self)
		if row.kind ~= "slider" or not row.it then return end
		local value = trimNum(self:GetValue())
		if not valuesEqual(value, row.it.info.value) then writeCvar(row.it, value) end
	end))
	attachRowTooltip(control.slider, row)
	attachRowTooltip(control.edit, row)
	row.controls.slider = control
	return control
end

local function buildStepper(row)
	local control = CreateFrame("Frame", nil, row)
	control:SetSize(Style.ListControlWidth, Style.ListRowHeightTall)
	control:SetPoint("LEFT", COL.control, 0)

	control.minus = ns.UI.Button(control, "-", 28, 22)
	control.minus:SetPoint("LEFT", 0, 0)
	control.edit = CreateFrame("EditBox", nil, control, "InputBoxTemplate")
	control.edit:SetSize(104, 20)
	control.edit:SetPoint("LEFT", control.minus, "RIGHT", 5, 0)
	control.edit:SetAutoFocus(false)
	control.plus = ns.UI.Button(control, "+", 28, 22)
	control.plus:SetPoint("LEFT", control.edit, "RIGHT", 5, 0)

	local function move(direction)
		if row.kind ~= "stepper" or not row.it then return end
		local current = tonumber(row.it.info.value)
		if not current then return end
		local step = tonumber(row.params and row.params.step) or 1
		writeCvar(row.it, trimNum(current + direction * step))
	end
	control.minus:SetScript("OnClick", G(function() move(-1) end))
	control.plus:SetScript("OnClick", G(function() move(1) end))
	control.edit:SetScript("OnEnterPressed", G(function(self)
		if row.kind == "stepper" and row.it and not valuesEqual(row.it.info.value, self:GetText()) then
			writeCvar(row.it, self:GetText())
		end
		self:ClearFocus()
	end))
	control.edit:SetScript("OnEscapePressed", function(self) restoreEdit(row, self, true) end)
	attachRowTooltip(control.minus, row)
	attachRowTooltip(control.edit, row)
	attachRowTooltip(control.plus, row)
	row.controls.stepper = control
	return control
end

local function enumDisplay(row, value)
	local labels = row.params and row.params.valueLabels
	local label = labels and labels[tostring(value)]
	return label and string.format("%s(%s)", L[label], tostring(value)) or tostring(value)
end

local function buildEnum(row)
	local control = CreateFrame("Frame", nil, row)
	control:SetSize(Style.ListControlWidth, Style.ListRowHeightTall)
	control:SetPoint("LEFT", COL.control, 0)

	local dropdown
	local hasDropdown = MenuUtil and pcall(function()
		dropdown = CreateFrame("DropdownButton", nil, control, "WowStyle1DropdownTemplate")
	end)
	if hasDropdown and dropdown then
		control.button = dropdown
		control.isDropdown = true
		dropdown:SetSize(230, 24)
		dropdown:SetPoint("LEFT", 0, 0)
		dropdown:SetupMenu(function(_, root)
			if row.kind ~= "enum" then return end
			local values = row.params and row.params.values or {}
			for i = 1, #values do
				local index = i
				root:CreateRadio(enumDisplay(row, values[i]),
					function()
						local currentValues = row.params and row.params.values or {}
						return row.it and currentValues[index] ~= nil
							and tostring(row.it.info.value) == tostring(currentValues[index])
					end,
					G(function()
						local currentValues = row.params and row.params.values or {}
						if row.kind == "enum" and row.it and currentValues[index] ~= nil then
							writeCvar(row.it, currentValues[index])
						end
					end))
			end
		end)
	else
		control.button = ns.UI.Button(control, "", 230, 22)
		control.button:SetPoint("LEFT", 0, 0)
		control.button:SetScript("OnClick", G(function()
			if row.kind ~= "enum" or not row.it then return end
			local values = row.params and row.params.values or {}
			if #values == 0 then return end
			local current, index = tostring(row.it.info.value), 0
			for i = 1, #values do
				if tostring(values[i]) == current then index = i break end
			end
			writeCvar(row.it, values[index % #values + 1])
		end))
	end
	attachRowTooltip(control.button, row)
	row.controls.enum = control
	return control
end

local function buildInput(row)
	local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	edit:SetSize(Style.ListControlWidth - 10, 20)
	edit:SetPoint("LEFT", COL.control + 4, 0)
	edit:SetAutoFocus(false)
	edit:SetScript("OnEnterPressed", G(function(self)
		if row.kind == "input" and row.it then writeCvar(row.it, self:GetText()) end
		self:ClearFocus()
	end))
	edit:SetScript("OnEscapePressed", function(self) restoreEdit(row, self, false) end)
	attachRowTooltip(edit, row)
	row.controls.input = edit
	return edit
end

local CONTROL_BUILDERS = {
	toggle = buildToggle,
	slider = buildSlider,
	stepper = buildStepper,
	enum = buildEnum,
	input = buildInput,
}

local function hideControls(row)
	for _, control in pairs(row.controls) do control:Hide() end
end

local function clearControlFocus(row)
	for kind, control in pairs(row.controls) do
		local edit = kind == "input" and control or control.edit
		if edit and edit:HasFocus() then edit:ClearFocus() end
	end
end

local function setControlEnabled(row, enabled)
	local control = row.controls[row.kind]
	if not control then return end
	if row.kind == "slider" then
		control.slider:SetEnabled(enabled)
		control.edit:SetEnabled(enabled)
	elseif row.kind == "stepper" then
		control.minus:SetEnabled(enabled)
		control.edit:SetEnabled(enabled)
		control.plus:SetEnabled(enabled)
	elseif row.kind == "enum" then
		control.button:SetEnabled(enabled)
	else
		control:SetEnabled(enabled)
	end
end

local function updateControl(row)
	local control = row.controls[row.kind]
	if not control then control = CONTROL_BUILDERS[row.kind](row) end
	local value = row.it.info.value
	if row.kind == "toggle" then
		control:SetChecked(tonumber(value) ~= nil and tonumber(value) ~= 0)
	elseif row.kind == "slider" then
		local range = row.params and row.params.range or {}
		local lo, hi = tonumber(range[1]) or 0, tonumber(range[2]) or 1
		local step = tonumber(range[3]) or 1
		control.slider:SetMinMaxValues(lo, hi)
		control.slider:SetValueStep(step)
		local numeric = tonumber(value)
		if numeric ~= nil then control.slider:SetValue(numeric) end
		if not control.edit:HasFocus() then control.edit:SetText(trimNum(value)) end
	elseif row.kind == "stepper" then
		if not control.edit:HasFocus() then control.edit:SetText(trimNum(value)) end
	elseif row.kind == "enum" then
		local display = enumDisplay(row, value)
		if control.isDropdown and control.button.OverrideText then
			control.button:OverrideText(display)
		elseif control.button.SetText then
			control.button:SetText(display)
		end
	elseif row.kind == "input" and not control:HasFocus() then
		control:SetText(tostring(value or ""))
	end
	control:Show()
end

local function firstSentence(text)
	if not text or text == "" then return "" end
	local positions = {}
	local newline = text:find("\n", 1, true)
	if newline then positions[#positions + 1] = newline end
	if ns.IsCJK() then
		local stop = text:find("。", 1, true)
		if stop then positions[#positions + 1] = stop end
	else
		local stop = text:find(". ", 1, true)
		if stop then positions[#positions + 1] = stop end
	end
	local cut
	for _, position in ipairs(positions) do
		if not cut or position < cut then cut = position end
	end
	return cut and text:sub(1, cut - 1) or text
end

local function dictionarySummary(key)
	local dictionary = ns.Data.encyclopedia and ns.Data.encyclopedia[key]
	if not dictionary then return "" end
	local text = ns.IsCJK() and dictionary.zh or dictionary.en
	return firstSentence(text)
end

local function buildRow(row, list)
	row.built = true
	row.list = list
	row.controls = {}
	Style.ListRow(row, false)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	row.star = CreateFrame("Button", nil, row)
	row.star:SetSize(Style.FavoriteButtonSize, Style.FavoriteButtonSize)
	row.star:SetPoint("LEFT", COL.name + 2, 0)
	row.star.text = row.star:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	row.star.text:SetPoint("CENTER")
	row.star:SetScript("OnClick", G(function()
		if row.it and not row.it.internalHeader then toggleFavorite(row.it.key) end
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
	row.name:SetPoint("TOPLEFT", COL.name + Style.ListNameInset, -3)
	row.name:SetWidth(COL.control - COL.name - Style.ListNameInset - Style.ListColumnGap)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	color(row.name, "SetTextColor", C.PrimaryText)

	row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
	row.sub:SetWidth(COL.control - COL.name - Style.ListNameInset - Style.ListColumnGap)
	row.sub:SetJustifyH("LEFT")
	row.sub:SetWordWrap(false)
	color(row.sub, "SetTextColor", C.SecondaryText)

	row.default = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	row.default:SetPoint("LEFT", COL.default, 0)
	row.default:SetWidth(COL.flags - COL.default - Style.ListColumnGap)
	row.default:SetJustifyH("LEFT")
	row.default:SetWordWrap(false)
	color(row.default, "SetTextColor", C.SecondaryText)

	row.flags = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.flags:SetPoint("LEFT", COL.flags, 0)
	row.flags:SetJustifyH("LEFT")
	row.flags:SetWordWrap(false)

	row.internalLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.internalLabel:SetPoint("LEFT", 8, 0)
	row.internalLabel:SetWidth(COL.flags + 140)
	row.internalLabel:SetJustifyH("LEFT")
	row.internalLabel:SetWordWrap(false)
	color(row.internalLabel, "SetTextColor", C.SecondaryText)
	row.internalLabel:Hide()

	local highlight = Style.Fill(row, "HIGHLIGHT", C.RowHover)
	highlight:SetAllPoints()

	row:SetScript("OnClick", G(function(self, button)
		if self.it and self.it.internalHeader then
			if button == "LeftButton" then
				self.list.internalExpanded = not self.list.internalExpanded
				self.list:Refresh()
			end
		elseif button == "RightButton" and self.it then
			showRowMenu(self, self.it)
		end
	end))
	row:SetScript("OnEnter", G(function(self)
		if self.it and not self.it.internalHeader then rowTooltip(self, self.it) end
	end))
	row:SetScript("OnLeave", G(function() GameTooltip:Hide() end))
end

local function updateInternalHeader(row, it, list)
	if row.it ~= it or row.kind ~= nil then clearControlFocus(row) end
	row.it = it
	row.kind, row.params = nil, nil
	Style.ListRow(row, false)
	hideControls(row)
	row.star:Hide()
	row.name:Hide()
	row.sub:Hide()
	row.default:Hide()
	row.flags:Hide()
	row.internalLabel:SetText((list.internalExpanded and "▾ " or "▸ ")
		.. string.format(L["Internal state records (%d) — saved by the game for progress; usually leave them alone"],
			it.count))
	row.internalLabel:Show()
	row:SetAlpha(1)
end

local function updateRow(row, it, even)
	local kind, params = ns.ControlKind(it.key, it.info)
	if row.it ~= it or row.kind ~= kind then clearControlFocus(row) end
	row.it = it
	row.kind, row.params = kind, params
	Style.ListRow(row, even)
	hideControls(row)
	row.internalLabel:Hide()
	row.star:Show()
	row.name:Show()
	row.sub:Show()
	row.default:Show()
	row.flags:Show()

	local favorite = ns.Favorites:IsFavorite(it.key)
	row.star.text:SetText(favorite and "★" or "☆")
	color(row.star.text, "SetTextColor", favorite and C.Favorite or C.Unfavorite)
	local control = row.params and row.params.control
	if control then
		row.name:SetText(ns.ControlLabel(control))
		row.sub:SetText(it.key)
	else
		row.name:SetText(it.key)
		row.sub:SetText(dictionarySummary(it.key))
	end
	row.default:SetText(tostring(it.info.default))
	row.flags:SetText(flagText(it, control or it.control))

	updateControl(row)
	local combatLocked = it.info.secure and ns.UI.combatLocked
	local enabled = not combatLocked and not it.info.readonly and not it.info.locked
	row:SetAlpha(combatLocked and 0.4 or 1)
	setControlEnabled(row, enabled)
end

function ns.UI.CreateCvarList(parent, getFilter)
	local list = CreateFrame("Frame", nil, parent)
	list.rowParity = {}
	list.internalExpanded = false

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
	headCol(L["Control"], COL.control)
	headCol(L["Default"], COL.default)
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
	view:SetElementExtent(Style.ListRowHeightTall)
	view:SetElementInitializer("Button", function(row, it)
		if not row.built then buildRow(row, list) end
		if it.internalHeader then
			updateInternalHeader(row, it, list)
		else
			updateRow(row, it, list.rowParity[it])
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(list.scrollBox, list.scrollBar, view)

	function list:Refresh()
		local searchText, category = getFilter()
		searchText = searchText or ""
		local results = ns.Search:Query(searchText, category)
		self.resultCount = #results
		local data = {}
		if searchText ~= "" then
			for _, it in ipairs(results) do data[#data + 1] = it end
		else
			local normal, internal = {}, {}
			for _, it in ipairs(results) do
				local group = ns.ControlKind_IsInternalState(it.key) and internal or normal
				group[#group + 1] = it
			end
			for _, it in ipairs(normal) do data[#data + 1] = it end
			if #internal > 0 then
				data[#data + 1] = { internalHeader = true, count = #internal }
				if self.internalExpanded then
					for _, it in ipairs(internal) do data[#data + 1] = it end
				end
			end
		end
		wipe(self.rowParity)
		local parity = 0
		for _, it in ipairs(data) do
			if not it.internalHeader then
				parity = parity + 1
				self.rowParity[it] = parity % 2 == 0
			end
		end
		self.scrollBox:SetDataProvider(CreateDataProvider(data), ScrollBoxConstants.RetainScrollPosition)
		if self.OnResultsChanged then self:OnResultsChanged(self.resultCount) end
	end

	function list:UpdateRows()
		self.scrollBox:ForEachFrame(function(row)
			if row.it and row.it.internalHeader then
				updateInternalHeader(row, row.it, self)
			elseif row.it then
				updateRow(row, row.it, self.rowParity[row.it])
			end
		end)
	end

	ns.Engine:AddListener(function()
		if list:IsShown() then list:UpdateRows() end
	end)

	return list
end
