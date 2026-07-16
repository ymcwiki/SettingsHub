local ADDON, ns = ...

local ROW_H = 22
local RING_SIZE = 500

StaticPopupDialogs["SETTINGSHUB_RESTORE_BASELINE"] = {
	text = "把本插件改过的 %d 项全部还原为首次改动前的值?",
	button1 = YES, button2 = NO,
	OnAccept = function()
		local n, failed = ns.Engine:RestoreAll("restore")
		ns.Print(string.format("已还原 %d 项,失败 %d 项", n, failed))
		ns.UI:Refresh()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["SETTINGSHUB_RESET_DEFAULTS"] = {
	text = "把本插件改过的 %d 项全部重置为暴雪默认值?这会丢弃你的当前设定。",
	button1 = YES, button2 = NO,
	OnAccept = function()
		local n, failed = ns.Engine:ResetAllToDefault()
		ns.Print(string.format("已回默认 %d 项,失败 %d 项", n, failed))
		ns.UI:Refresh()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function collectEntries()
	local log = ns.db.global.undoLog
	local out = {}
	for i = 0, RING_SIZE - 1 do
		local p = ((log.head - 2 - i) % RING_SIZE) + 1
		local e = log.entries[p]
		if not e then break end
		out[#out + 1] = e
	end
	return out
end

local SOURCE_NAMES = {
	user = "手动", import = "导入", replay = "重放", undo = "撤销", reset = "回默认",
	uninstall = "卸载还原", restore = "还原", test = "自测", profile = "profile",
}

local function buildRow(row)
	row.built = true
	row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.time:SetPoint("LEFT", 2, 0)
	row.source = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.source:SetPoint("LEFT", 92, 0)
	row.key = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.key:SetPoint("LEFT", 160, 0)
	row.key:SetWidth(250)
	row.key:SetJustifyH("LEFT")
	row.key:SetWordWrap(false)
	row.change = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.change:SetPoint("LEFT", 416, 0)
	row.change:SetWidth(240)
	row.change:SetJustifyH("LEFT")
	row.change:SetWordWrap(false)
	row.undoBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.undoBtn:SetSize(56, 18)
	row.undoBtn:SetPoint("RIGHT", -4, 0)
	row.undoBtn:SetText("撤销")
	row.undoBtn:SetScript("OnClick", function()
		if row.entry then
			ns.Engine:Undo(row.entry)
			ns.UI:Refresh()
		end
	end)
end

local function updateRow(row, e)
	row.entry = e
	row.time:SetText(date("%m-%d %H:%M:%S", e.t))
	row.source:SetText(SOURCE_NAMES[e.source] or e.source)
	row.key:SetText(e.key)
	if e.bulk then
		row.change:SetFormattedText("[整域快照] %s", tostring(e.new))
	else
		row.change:SetFormattedText("%s 改为 %s", tostring(e.old), tostring(e.new))
	end
	if e.failed then
		row.change:SetTextColor(1, 0.3, 0.3)
	else
		row.change:SetTextColor(0.9, 0.9, 0.9)
	end
	local canUndo = not e.failed and not e.undone and e.source ~= "undo"
	row.undoBtn:SetShown(canUndo)
	if e.undone then row.source:SetText((SOURCE_NAMES[e.source] or e.source) .. "|cff888888(已撤销)|r") end
end

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)

	local undoLast = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	undoLast:SetSize(120, 22)
	undoLast:SetPoint("TOPLEFT", 0, 0)
	undoLast:SetText("撤销最近一次")
	undoLast:SetScript("OnClick", function()
		ns.Engine:UndoLast()
		ns.UI:Refresh()
	end)

	local restore = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	restore:SetSize(140, 22)
	restore:SetPoint("LEFT", undoLast, "RIGHT", 8, 0)
	restore:SetText("还原为改动前")
	restore:SetScript("OnClick", function()
		local n = 0
		for _ in pairs(ns.db.global.baseline) do n = n + 1 end
		if n == 0 then ns.Print("本插件还没有改过任何项") return end
		StaticPopup_Show("SETTINGSHUB_RESTORE_BASELINE", n)
	end)

	local resetAll = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	resetAll:SetSize(140, 22)
	resetAll:SetPoint("LEFT", restore, "RIGHT", 8, 0)
	resetAll:SetText("全部回暴雪默认")
	resetAll:SetScript("OnClick", function()
		local n = 0
		for _ in pairs(ns.db.global.baseline) do n = n + 1 end
		if n == 0 then ns.Print("本插件还没有改过任何项") return end
		StaticPopup_Show("SETTINGSHUB_RESET_DEFAULTS", n)
	end)

	page.status = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.status:SetPoint("LEFT", resetAll, "RIGHT", 16, 0)

	page.scrollBox = CreateFrame("Frame", nil, page, "WowScrollBoxList")
	page.scrollBox:SetPoint("TOPLEFT", 0, -30)
	page.scrollBox:SetPoint("BOTTOMRIGHT", -22, 2)
	page.scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
	page.scrollBar:SetPoint("TOPLEFT", page.scrollBox, "TOPRIGHT", 4, 0)
	page.scrollBar:SetPoint("BOTTOMLEFT", page.scrollBox, "BOTTOMRIGHT", 4, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_H)
	view:SetElementInitializer("Frame", function(row, e)
		if not row.built then buildRow(row) end
		updateRow(row, e)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(page.scrollBox, page.scrollBar, view)

	function page:OnPageShow()
		self.scrollBox:SetDataProvider(CreateDataProvider(collectEntries()))
		local qn = ns.CombatQueue:Size()
		local fn = #ns.Engine.failures
		local parts = {}
		if qn > 0 then parts[#parts + 1] = string.format("|cffffcc00战斗队列 %d 项|r", qn) end
		if fn > 0 then parts[#parts + 1] = string.format("|cffff5555本次会话失败 %d 项|r", fn) end
		self.status:SetText(table.concat(parts, "  "))
	end

	ns.Engine:AddListener(function()
		if page:IsShown() then page:OnPageShow() end
	end)

	return page
end

ns.UI:RegisterPage("log", "日志与还原", build)
