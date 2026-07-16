local ADDON, ns = ...

local ROW_H = 24
local CAT_W = 110

-- ConsoleGetAllCommands 的 category 数字段位(census 口径:4=Game 最多,1=Graphics,5=Default,0=Debug,7=Sound)
local CATEGORY_NAMES = {
	[0] = "Debug", [1] = "Graphics", [2] = "Console", [3] = "Combat", [4] = "Game",
	[5] = "Default", [6] = "Net", [7] = "Sound", [8] = "GM", [10] = "Bnet",
}

local COL = { name = 0, value = 320, default = 445, scope = 570, flags = 630 }

StaticPopupDialogs["SETTINGSHUB_COPY"] = {
	text = "Ctrl+C 复制:",
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
	if scope == "account" then return "|cff4da6ff账号|r" end
	if scope == "character" then return "|cff66cc66角色|r" end
	return "|cff999999本机|r"
end

local function flagText(it)
	local parts = {}
	if it.info.secure then parts[#parts + 1] = "|cffff5555安全|r" end
	if it.info.readonly then parts[#parts + 1] = "|cff888888只读|r" end
	if it.info.locked then parts[#parts + 1] = "|cff888888锁定|r" end
	if it.control and it.control.requiresReload then parts[#parts + 1] = "|cffffcc00重载|r" end
	if it.control and it.control.requiresRestart then parts[#parts + 1] = "|cffff8800重启|r" end
	return table.concat(parts, " ")
end

local editor

local function commitEdit()
	local it = editor.it
	editor:Hide()
	if not it then return end
	local r, err = ns.Engine:Set("cvar", it.key, editor:GetText(), "user")
	if r == "failed" then
		ns.Print(string.format("%s 写入失败(%s):可能只读或值非法", it.key, tostring(err)))
	elseif r == "queued" then
		ns.Print(string.format("%s 战斗中已排队,脱战后应用", it.key))
	end
	ns.UI:Refresh()
end

local function openEditor(anchor, it)
	if it.info.secure and ns.UI.combatLocked then
		ns.Print("战斗中 secure 项已锁定,脱战后再改")
		return
	end
	if not editor then
		editor = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
		editor:SetSize(110, 20)
		editor:SetAutoFocus(true)
		editor:SetScript("OnEnterPressed", commitEdit)
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
		root:CreateButton(string.format("回默认(%s)", tostring(it.info.default)), function()
			ns.Engine:ResetToDefault("cvar", it.key)
			ns.UI:Refresh()
		end)
		root:CreateButton("复制名称", function()
			StaticPopup_Show("SETTINGSHUB_COPY", nil, nil, it.key)
		end)
		root:CreateButton("复制设置命令", function()
			StaticPopup_Show("SETTINGSHUB_COPY", nil, nil,
				string.format("/console %s %s", it.key, tostring(it.info.value)))
		end)
		if ns.Profiles then
			root:CreateButton("把当前值记入激活 profile", function()
				ns.Profiles:Pin("cvar", it.key)
			end)
		end
	end)
end

local function rowTooltip(row, it)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(it.key, 1, 1, 1)
	if it.control and it.control.text and it.control.text.zh ~= "" then
		GameTooltip:AddLine(it.control.text.zh, 0.9, 0.9, 0.6, true)
	end
	if it.info.help ~= "" then
		GameTooltip:AddLine(it.info.help, 0.6, 0.6, 0.6, true)
	end
	GameTooltip:AddDoubleLine("当前值", tostring(it.info.value), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("默认值", tostring(it.info.default), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("作用域", scopeBadge(it.info.scope), 0.8, 0.8, 0.8)
	local blame = ns.Blame:Get(it.key)
	if blame then
		GameTooltip:AddDoubleLine("最后修改", string.format("%s(%s)", blame.by, date("%m-%d %H:%M", blame.t)),
			0.8, 0.8, 0.8, 1, 0.7, 0.3)
	end
	local v = it.control and it.control.version
	if v and v.added then
		GameTooltip:AddDoubleLine("加入版本", v.added, 0.8, 0.8, 0.8, 0.6, 0.9, 1)
	end
	GameTooltip:Show()
end

local function buildRow(row)
	row.built = true
	row:RegisterForClicks("RightButtonUp")
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", COL.name + 4, 0)
	row.name:SetWidth(COL.value - COL.name - 10)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.valueBtn = CreateFrame("Button", nil, row)
	row.valueBtn:SetPoint("LEFT", COL.value, 0)
	row.valueBtn:SetSize(COL.default - COL.value - 6, ROW_H)
	row.valueText = row.valueBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.valueText:SetPoint("LEFT")
	row.valueText:SetJustifyH("LEFT")
	row.valueBtn:SetScript("OnClick", function() openEditor(row.valueBtn, row.it) end)

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

	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then showRowMenu(self, self.it) end
	end)
	row:SetScript("OnEnter", function(self) rowTooltip(self, self.it) end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function updateRow(row, it)
	row.it = it
	local curated = it.control and it.control.text and it.control.text.zh ~= ""
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
	headCol("名称", COL.name + 4)
	headCol("当前值(点击编辑)", COL.value)
	headCol("默认值", COL.default)
	headCol("作用域", COL.scope)
	headCol("标签", COL.flags)

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
		self.count:SetFormattedText("%d / %d 项", #results, ns.Enum.count)
	end

	function page:RebuildCategories()
		local counts = ns.Search:CategoryCounts()
		local sorted = {}
		for id, n in pairs(counts) do sorted[#sorted + 1] = { id = id, n = n } end
		table.sort(sorted, function(a, b) return a.n > b.n end)
		table.insert(sorted, 1, { id = nil, n = ns.Enum.count, all = true })
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
			local label = c.all and "全部" or (CATEGORY_NAMES[c.id] or ("类别" .. tostring(c.id)))
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

ns.UI:RegisterPage("browser", "浏览器", build)
