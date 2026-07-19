local ADDON, ns = ...
local L = ns.L
local G = ns.Guard

local M = { pages = {}, pageOrder = {}, combatLocked = false }
ns.UI = M

-- StaticPopup 的 editBox 字段 11.x 起不保证存在(实机:12.0.7 上新建 profile
-- 弹窗点接受无反应),新旧取法都试
function M.PopupEditBox(dialog)
	if dialog.GetEditBox then return dialog:GetEditBox() end
	return dialog.editBox or dialog.EditBox
end

local frame, searchBox, searchHint, contentArea, combatBanner, nav
local navButtons = {}
local navSeparators = {}
local currentPageKey

function M:RegisterPage(key, title, builder, opts)
	self.pages[key] = { title = title, build = builder, opts = opts or {} }
	self.pageOrder[#self.pageOrder + 1] = key
end

local function pageVisible(page)
	return page and (not page.opts.visible or page.opts.visible())
end

local function firstVisiblePage()
	for _, key in ipairs(M.pageOrder) do
		if pageVisible(M.pages[key]) then return key end
	end
end

local function selectPage(key)
	local page = M.pages[key]
	if not pageVisible(page) then return end
	if not page.frame then
		page.frame = page.build(contentArea)
		page.frame:SetAllPoints(contentArea)
	end
	for k, p in pairs(M.pages) do
		if p.frame then p.frame:SetShown(k == key) end
	end
	for k, btn in pairs(navButtons) do
		if btn:IsShown() then ns.Style.NavRow(btn, k == key) end
	end
	currentPageKey = key
	M.currentPageKey = key
	if page.frame.OnPageShow then page.frame:OnPageShow() end
end

function M:SelectPage(key)
	if frame and frame:IsShown() then selectPage(key) end
end

function M:OnSearchChanged(text)
	-- 任何页面输入搜索都跳回「全部设置」展示结果；主题页自身始终是全量。
	if currentPageKey ~= "all" then selectPage("all") end
	local page = self.pages.all
	if page and page.frame and page.frame.OnSearch then
		page.frame:OnSearch(text)
	end
end

function M:GetSearchText()
	return searchBox and searchBox:GetText() or ""
end

local function buildFrame()
	local Style = ns.Style
	frame = CreateFrame("Frame", "SettingsHubFrame", UIParent, "BackdropTemplate")
	frame:SetSize(Style.FrameWidth, Style.FrameHeight)
	frame:SetPoint("CENTER")
	Style.Panel(frame)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetFrameStrata("HIGH")
	frame:Hide()
	tinsert(UISpecialFrames, "SettingsHubFrame")

	local titleBar = Style.Fill(frame, "BACKGROUND", Style.Colors.NavBackground)
	titleBar:SetPoint("TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", -1, -1)
	titleBar:SetHeight(Style.TitleBarHeight)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", titleBar, "LEFT", Style.TitleInset, 0)
	title:SetText("SettingsHub")
	Style.SetColor(title, "SetTextColor", Style.Colors.PrimaryText)

	local close = Style.CloseButton(frame)
	close:SetPoint("RIGHT", titleBar, "RIGHT", -Style.TitleInset, 0)

	searchBox = Style.SearchBox(frame, L["Search"])
	searchBox:SetPoint("LEFT", title, "RIGHT", 24, 0)
	searchBox:HookScript("OnTextChanged", G(function(box, userInput)
		if userInput then M:OnSearchChanged(box:GetText()) end
	end))

	searchHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	searchHint:SetPoint("LEFT", searchBox, "RIGHT", Style.SearchHintGap, 0)
	searchHint:SetText(L["Filters: tag:favorite tag:modified tag:new tag:secure tag:hidden"])
	Style.SetColor(searchHint, "SetTextColor", Style.Colors.SecondaryText)

	combatBanner = CreateFrame("Frame", nil, frame)
	combatBanner.text = combatBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	combatBanner.text:SetPoint("CENTER")
	combatBanner.text:SetText(L["In combat: secure values locked, writes will queue"])
	Style.SetColor(combatBanner.text, "SetTextColor", Style.Colors.Combat)
	combatBanner:SetSize(combatBanner.text:GetStringWidth() + Style.CombatPaddingX * 2,
		combatBanner.text:GetStringHeight() + Style.CombatPaddingY * 2)
	local combatBackground = Style.Fill(combatBanner, "BACKGROUND", Style.Colors.CombatBackground)
	combatBackground:SetAllPoints()
	combatBanner:SetPoint("RIGHT", close, "LEFT", -12, 0)
	combatBanner:Hide()

	nav = CreateFrame("Frame", nil, frame)
	nav:SetPoint("TOPLEFT", 0, -Style.NavTop)
	nav:SetPoint("BOTTOMLEFT", 0, 0)
	nav:SetWidth(Style.NavWidth + Style.FrameInset)
	local navBackground = Style.Fill(nav, "BACKGROUND", Style.Colors.NavBackground)
	navBackground:SetAllPoints()
	local navBorder = Style.Fill(nav, "BORDER", Style.Colors.Separator)
	navBorder:SetPoint("TOPRIGHT")
	navBorder:SetPoint("BOTTOMRIGHT")
	navBorder:SetWidth(Style.SeparatorHeight)

	contentArea = CreateFrame("Frame", nil, frame)
	contentArea:SetPoint("TOPLEFT", nav, "TOPRIGHT", Style.FrameInset, -Style.FrameInset)
	contentArea:SetPoint("BOTTOMRIGHT", -Style.FrameInset, Style.FrameInset)

	M:RebuildNavigation()
end

function M:RebuildNavigation()
	if not nav then return end
	local Style = ns.Style
	for _, btn in pairs(navButtons) do btn:Hide() end
	for _, separator in ipairs(navSeparators) do separator:Hide() end

	local y, separatorIndex = 0, 0
	for _, key in ipairs(M.pageOrder) do
		local page = M.pages[key]
		if pageVisible(page) then
			if page.opts.sepBefore then
				separatorIndex = separatorIndex + 1
				local separator = navSeparators[separatorIndex]
				if not separator then
					separator = Style.Separator(nav)
					navSeparators[separatorIndex] = separator
				end
				y = y - Style.NavSeparatorGap / 2
				separator:ClearAllPoints()
				separator:SetPoint("TOPLEFT", Style.FrameInset + 6, y)
				separator:SetPoint("TOPRIGHT", -6, y)
				separator:Show()
				y = y - Style.NavSeparatorGap / 2
			end

			local btn = navButtons[key]
			if not btn then
				btn = CreateFrame("Button", nil, nav)
				btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				btn.text:SetPoint("LEFT", Style.NavTextInset, 0)
				local highlight = Style.Fill(btn, "HIGHLIGHT", Style.Colors.NavHover)
				highlight:SetAllPoints()
				local pageKey = key
				btn:SetScript("OnClick", G(function() selectPage(pageKey) end))
				navButtons[key] = btn
			end
			btn:ClearAllPoints()
			btn:SetSize(Style.NavWidth, Style.NavRowHeight)
			btn:SetPoint("TOPLEFT", Style.FrameInset, y)
			btn.text:SetText(page.title)
			Style.NavRow(btn, currentPageKey == key)
			btn:Show()
			y = y - Style.NavRowHeight - Style.NavGap
		end
	end
end

function M:Refresh()
	if not (frame and frame:IsShown()) then return end
	local page = self.pages[currentPageKey]
	if page and page.frame and page.frame.OnPageShow then
		page.frame:OnPageShow()
	end
end

function M:SetCombatLock(locked)
	self.combatLocked = locked
	if frame and frame:IsShown() then
		combatBanner:SetShown(locked)
		searchHint:SetShown(not locked)
		self:Refresh()
	end
end

function M:Toggle()
	if frame and frame:IsShown() then
		frame:Hide()
		return
	end
	-- 每次打开重枚举回灌(AIO #126 教训),再重建搜索索引
	ns.Enum:Refresh()
	ns.Search:Rebuild()
	if not frame then
		buildFrame()
	else
		self:RebuildNavigation()
	end
	frame:Show()
	combatBanner:SetShown(self.combatLocked)
	searchHint:SetShown(not self.combatLocked)
	local target = pageVisible(self.pages[currentPageKey]) and currentPageKey or firstVisiblePage()
	selectPage(target)
	searchBox:SetFocus()
end
