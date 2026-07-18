local ADDON, ns = ...
local L = ns.L

local ROW_H = 22
local RING_SIZE = 500
local CONFLICT_MAX_ROWS = 6

StaticPopupDialogs["SETTINGSHUB_RESTORE_BASELINE"] = {
	text = L["Restore all %d values this addon has changed to their pre-change originals?"],
	button1 = YES, button2 = NO,
	OnAccept = function()
		local n, queued, failed = ns.Engine:RestoreAll("restore")
		ns.Print(string.format(L["Restored %d values, %d failed"], n, failed))
		if queued > 0 then ns.Print(string.format(L["%d queued in combat"], queued)) end
		ns.UI:Refresh()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["SETTINGSHUB_RESET_DEFAULTS"] = {
	text = L["Reset all %d values this addon has changed to Blizzard defaults? Your current settings will be lost."],
	button1 = YES, button2 = NO,
	OnAccept = function()
		local n, queued, failed = ns.Engine:ResetAllToDefault()
		ns.Print(string.format(L["Reset %d values to default, %d failed"], n, failed))
		if queued > 0 then ns.Print(string.format(L["%d queued in combat"], queued)) end
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
	user = L["manual"], import = L["import"], replay = L["replay"], undo = L["undo"],
	reset = L["reset"], uninstall = L["uninstall"], restore = L["restore"], test = L["selftest"],
	profile = L["profile"], snapshot = L["snapshot"], pack = L["pack"], trial = L["trial"],
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
	row.undoBtn:SetText(L["Undo"])
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
		row.change:SetFormattedText(L["[domain snapshot] %s"], tostring(e.new))
	else
		row.change:SetFormattedText(L["%s changed to %s"], tostring(e.old), tostring(e.new))
	end
	if e.failed then
		row.change:SetTextColor(1, 0.3, 0.3)
	else
		row.change:SetTextColor(0.9, 0.9, 0.9)
	end
	local canUndo = not e.failed and not e.undone and e.source ~= "undo"
	row.undoBtn:SetShown(canUndo)
	if e.undone then row.source:SetText((SOURCE_NAMES[e.source] or e.source) .. "|cff888888(" .. L["undone"] .. ")|r") end
end

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)

	local undoLast = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	undoLast:SetSize(120, 22)
	undoLast:SetPoint("TOPLEFT", 0, 0)
	undoLast:SetText(L["Undo last"])
	undoLast:SetScript("OnClick", function()
		ns.Engine:UndoLast()
		ns.UI:Refresh()
	end)

	local restore = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	restore:SetSize(140, 22)
	restore:SetPoint("LEFT", undoLast, "RIGHT", 8, 0)
	restore:SetText(L["Restore originals"])
	restore:SetScript("OnClick", function()
		local n = 0
		for _ in pairs(ns.db.global.baseline) do n = n + 1 end
		if n == 0 then ns.Print(L["This addon has not changed anything yet"]) return end
		StaticPopup_Show("SETTINGSHUB_RESTORE_BASELINE", n)
	end)

	local resetAll = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	resetAll:SetSize(140, 22)
	resetAll:SetPoint("LEFT", restore, "RIGHT", 8, 0)
	resetAll:SetText(L["All to Blizzard defaults"])
	resetAll:SetScript("OnClick", function()
		local n = 0
		for _ in pairs(ns.db.global.baseline) do n = n + 1 end
		if n == 0 then ns.Print(L["This addon has not changed anything yet"]) return end
		StaticPopup_Show("SETTINGSHUB_RESET_DEFAULTS", n)
	end)

	page.status = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.status:SetPoint("LEFT", resetAll, "RIGHT", 16, 0)

	-- T3 冲突区:期望态被同一外部来源跨登录反复覆盖(≥3 次)的项,给出处置按钮
	page.conflictHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	page.conflictHeader:SetPoint("TOPLEFT", 0, -32)
	page.conflictHeader:SetText("|cffff7733" .. L["Conflicts: these values keep getting overwritten by other addons"] .. "|r")
	page.conflictHeader:Hide()
	page.conflictRows = {}
	page.conflictOverflow = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	page.conflictOverflow:Hide()

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

	local function conflictRow(i)
		local r = page.conflictRows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, page)
		r:SetSize(700, 20)
		r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.text:SetPoint("LEFT", 8, 0)
		r.text:SetWidth(430)
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r.stopBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
		r.stopBtn:SetSize(96, 18)
		r.stopBtn:SetPoint("LEFT", 444, 0)
		r.stopBtn:SetText(L["Stop managing"])
		r.stopBtn:SetScript("OnClick", function()
			if r.conflict then
				ns.Conflicts:StopManaging(r.conflict.key)
				ns.Print(string.format(L["%s removed from desired state, no longer replayed"], r.conflict.key))
				page:OnPageShow()
			end
		end)
		r.keepBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
		r.keepBtn:SetSize(96, 18)
		r.keepBtn:SetPoint("LEFT", r.stopBtn, "RIGHT", 6, 0)
		r.keepBtn:SetText(L["Keep mine"])
		r.keepBtn:SetScript("OnClick", function()
			if r.conflict then
				ns.Conflicts:Acknowledge(r.conflict.key, r.conflict.by)
				ns.Print(string.format(L["%s kept: still replayed to your desired value each login"], r.conflict.key))
				page:OnPageShow()
			end
		end)
		page.conflictRows[i] = r
		return r
	end

	function page:RefreshConflicts()
		local list = ns.Conflicts and ns.Conflicts:List() or {}
		for _, r in ipairs(self.conflictRows) do r:Hide() end
		self.conflictOverflow:Hide()
		local y = -30
		if #list > 0 then
			self.conflictHeader:Show()
			y = y - 20
			local shown = math.min(#list, CONFLICT_MAX_ROWS)
			for i = 1, shown do
				local c = list[i]
				local r = conflictRow(i)
				r:SetPoint("TOPLEFT", 0, y)
				r.conflict = c
				r.text:SetFormattedText(L["%s overwritten by %s on %d logins"], c.key, c.by, c.logins)
				r:Show()
				y = y - 22
			end
			if #list > shown then
				self.conflictOverflow:SetPoint("TOPLEFT", 8, y)
				self.conflictOverflow:SetFormattedText(L["...and %d more"], #list - shown)
				self.conflictOverflow:Show()
				y = y - 18
			end
			y = y - 6
		else
			self.conflictHeader:Hide()
		end
		self.scrollBox:ClearAllPoints()
		self.scrollBox:SetPoint("TOPLEFT", 0, y)
		self.scrollBox:SetPoint("BOTTOMRIGHT", -22, 2)
	end

	function page:OnPageShow()
		self:RefreshConflicts()
		self.scrollBox:SetDataProvider(CreateDataProvider(collectEntries()))
		local qn = ns.CombatQueue:Size()
		local fn = #ns.Engine.failures
		local parts = {}
		if qn > 0 then parts[#parts + 1] = string.format("|cffffcc00" .. L["%d queued in combat"] .. "|r", qn) end
		if fn > 0 then parts[#parts + 1] = string.format("|cffff5555" .. L["%d failed this session"] .. "|r", fn) end
		self.status:SetText(table.concat(parts, "  "))
	end

	ns.Engine:AddListener(function()
		if page:IsShown() then page:OnPageShow() end
	end)

	return page
end

ns.UI:RegisterPage("log", L["Log & Restore"], build)
