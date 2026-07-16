local ADDON, ns = ...

local M = { pages = {}, pageOrder = {}, combatLocked = false }
ns.UI = M

local FRAME_W, FRAME_H = 1000, 640
local NAV_W = 150

local frame, searchBox, contentArea, combatBanner
local navButtons = {}
local currentPageKey

function M:RegisterPage(key, title, builder)
	self.pages[key] = { title = title, build = builder }
	self.pageOrder[#self.pageOrder + 1] = key
end

local function selectPage(key)
	local page = M.pages[key]
	if not page then return end
	if not page.frame then
		page.frame = page.build(contentArea)
		page.frame:SetAllPoints(contentArea)
	end
	for k, p in pairs(M.pages) do
		if p.frame then p.frame:SetShown(k == key) end
	end
	for k, btn in pairs(navButtons) do
		btn.text:SetTextColor(k == key and 1 or 0.9, k == key and 0.82 or 0.9, k == key and 0 or 0.9)
	end
	currentPageKey = key
	if page.frame.OnPageShow then page.frame:OnPageShow() end
end

function M:SelectPage(key)
	if frame and frame:IsShown() then selectPage(key) end
end

function M:OnSearchChanged(text)
	-- 任何页面输入搜索都跳回浏览器页展示结果
	if currentPageKey ~= "browser" then selectPage("browser") end
	local page = self.pages.browser
	if page and page.frame and page.frame.OnSearch then
		page.frame:OnSearch(text)
	end
end

function M:GetSearchText()
	return searchBox and searchBox:GetText() or ""
end

local function buildFrame()
	frame = CreateFrame("Frame", "SettingsHubFrame", UIParent, "BackdropTemplate")
	frame:SetSize(FRAME_W, FRAME_H)
	frame:SetPoint("CENTER")
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetFrameStrata("HIGH")
	frame:Hide()
	tinsert(UISpecialFrames, "SettingsHubFrame")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("SettingsHub")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	searchBox:SetSize(280, 22)
	searchBox:SetPoint("TOPLEFT", title, "TOPRIGHT", 24, -2)
	searchBox:SetAutoFocus(false)
	searchBox:HookScript("OnTextChanged", function(box, userInput)
		if userInput then M:OnSearchChanged(box:GetText()) end
	end)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
	hint:SetText("过滤词: tag:modified tag:new tag:secure tag:hidden")

	combatBanner = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	combatBanner:SetPoint("TOPRIGHT", close, "TOPLEFT", -12, -8)
	combatBanner:SetTextColor(1, 0.3, 0.3)
	combatBanner:SetText("战斗中:secure 项已锁定,写入将排队")
	combatBanner:Hide()

	local nav = CreateFrame("Frame", nil, frame)
	nav:SetPoint("TOPLEFT", 12, -48)
	nav:SetPoint("BOTTOMLEFT", 12, 12)
	nav:SetWidth(NAV_W)

	contentArea = CreateFrame("Frame", nil, frame)
	contentArea:SetPoint("TOPLEFT", nav, "TOPRIGHT", 6, 0)
	contentArea:SetPoint("BOTTOMRIGHT", -12, 12)

	local y = 0
	for _, key in ipairs(M.pageOrder) do
		local page = M.pages[key]
		local btn = CreateFrame("Button", nil, nav)
		btn:SetSize(NAV_W, 22)
		btn:SetPoint("TOPLEFT", 0, y)
		btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		btn.text:SetPoint("LEFT", 6, 0)
		btn.text:SetText(page.title)
		local hl = btn:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
		btn:SetScript("OnClick", function() selectPage(key) end)
		navButtons[key] = btn
		y = y - 24
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
		self:Refresh()
	end
end

function M:Toggle()
	if not frame then buildFrame() end
	if frame:IsShown() then
		frame:Hide()
		return
	end
	-- 每次打开重枚举回灌(AIO #126 教训),再重建搜索索引
	ns.Enum:Refresh()
	ns.Search:Rebuild()
	frame:Show()
	combatBanner:SetShown(self.combatLocked)
	selectPage(currentPageKey or self.pageOrder[1])
	searchBox:SetFocus()
end
