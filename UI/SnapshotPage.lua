local ADDON, ns = ...
local L = ns.L

local ROW_H = 20
local LIST_ROWS = 10

StaticPopupDialogs["SETTINGSHUB_SNAPSHOT_EVICT"] = {
	text = L["Snapshot limit of %d reached. Delete the oldest [%s] and continue?"],
	button1 = YES, button2 = NO,
	OnAccept = function(_, cb)
		cb()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["SETTINGSHUB_SNAPSHOT_DELETE"] = {
	text = L["Delete snapshot [%s]?"],
	button1 = YES, button2 = NO,
	OnAccept = function(_, cb)
		cb()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["SETTINGSHUB_SNAPSHOT_RESTORE"] = {
	text = L["Write %d checked values from snapshot [%s] back to the game? Every write is undoable from the Log page."],
	button1 = YES, button2 = NO,
	OnAccept = function(_, cb)
		cb()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)
	page.checked = {}

	-- 顶部:命名 + 新建 + 计数
	local nameLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameLabel:SetPoint("TOPLEFT", 4, -6)
	nameLabel:SetText(L["Name:"])
	local nameBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	nameBox:SetSize(160, 20)
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
	nameBox:SetAutoFocus(false)

	local createBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	createBtn:SetSize(110, 22)
	createBtn:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
	createBtn:SetText(L["New snapshot"])

	page.countText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.countText:SetPoint("LEFT", createBtn, "RIGHT", 12, 0)

	local function doCreate(evict)
		local name = nameBox:GetText():match("^%s*(.-)%s*$")
		if name == "" then name = date("%m-%d %H:%M") end
		local snap, err = ns.Snapshots:Create(name, evict)
		if snap then
			nameBox:SetText("")
			ns.Print(string.format(L["Snapshot [%s] created (%d entries)"], snap.name, snap.count))
			page:OnPageShow()
		elseif err == "full" then
			local oldest = ns.Snapshots:Oldest()
			StaticPopup_Show("SETTINGSHUB_SNAPSHOT_EVICT", ns.Snapshots.MAX, oldest and oldest.name or "?",
				function() doCreate(true) end)
		else
			ns.Print(L["CVars not fully loaded yet, try again in a moment"])
		end
	end
	createBtn:SetScript("OnClick", function() doCreate(false) end)

	-- 对比基准:当前实机值或另一份快照
	page.baselineIdx = 0
	local baseBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	baseBtn:SetSize(200, 20)
	baseBtn:SetPoint("TOPRIGHT", -26, -6)
	local function baselineName()
		if page.baselineIdx == 0 then return L["Live values"] end
		local s = ns.Snapshots:List()[page.baselineIdx]
		return s and s.name or L["Live values"]
	end
	local function refreshBaseBtn()
		baseBtn:SetText(L["Compare against: "] .. baselineName())
	end
	baseBtn:SetScript("OnClick", function()
		page.baselineIdx = (page.baselineIdx + 1) % (#ns.Snapshots:List() + 1)
		refreshBaseBtn()
		if page.diffSnap then page:RunDiff(page.diffSnap) end
	end)

	-- 快照列表(上限 10,固定行)
	page.listRows = {}
	local function listRow(i)
		local r = page.listRows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, page)
		r:SetSize(820, 22)
		r:SetPoint("TOPLEFT", 0, -30 - (i - 1) * 22)
		r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.text:SetPoint("LEFT", 4, 0)
		r.text:SetWidth(470)
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r.cmpBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
		r.cmpBtn:SetSize(70, 18)
		r.cmpBtn:SetPoint("LEFT", 480, 0)
		r.cmpBtn:SetText(L["Compare"])
		r.cmpBtn:SetScript("OnClick", function() page:RunDiff(r.snap) end)
		r.delBtn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
		r.delBtn:SetSize(70, 18)
		r.delBtn:SetPoint("LEFT", r.cmpBtn, "RIGHT", 6, 0)
		r.delBtn:SetText(L["Delete"])
		r.delBtn:SetScript("OnClick", function()
			StaticPopup_Show("SETTINGSHUB_SNAPSHOT_DELETE", r.snap.name, nil, function()
				ns.Snapshots:Delete(r.snap)
				if page.diffSnap == r.snap then page.diffSnap = nil end
				page.baselineIdx = 0
				page:OnPageShow()
			end)
		end)
		page.listRows[i] = r
		return r
	end

	-- 差异区:标题 + 全选/清空/恢复 + 滚动列表
	local diffTop = -30 - LIST_ROWS * 22 - 8
	page.diffTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	page.diffTitle:SetPoint("TOPLEFT", 0, diffTop)
	page.diffTitle:SetText(L["Pick a snapshot and hit Compare; check changed rows to restore them selectively"])

	local checkAll = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	checkAll:SetSize(90, 20)
	checkAll:SetPoint("TOPLEFT", 0, diffTop - 20)
	checkAll:SetText(L["Check all"])
	checkAll:SetScript("OnClick", function()
		if not page.diff then return end
		for _, c in ipairs(page.diff.changed) do page.checked[c.key] = true end
		page:RenderDiff()
	end)
	local checkNone = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	checkNone:SetSize(90, 20)
	checkNone:SetPoint("LEFT", checkAll, "RIGHT", 6, 0)
	checkNone:SetText(L["Uncheck all"])
	checkNone:SetScript("OnClick", function()
		wipe(page.checked)
		page:RenderDiff()
	end)
	local restoreBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	restoreBtn:SetSize(130, 20)
	restoreBtn:SetPoint("LEFT", checkNone, "RIGHT", 6, 0)
	restoreBtn:SetText(L["Restore checked"])
	restoreBtn:SetScript("OnClick", function()
		if not page.diffSnap then return end
		local keys = {}
		for key, on in pairs(page.checked) do
			if on then keys[#keys + 1] = key end
		end
		if #keys == 0 then
			ns.Print(L["Nothing checked"])
			return
		end
		local snap = page.diffSnap
		StaticPopup_Show("SETTINGSHUB_SNAPSHOT_RESTORE", #keys, snap.name, function()
			local n, failed = ns.Snapshots:Restore(snap, keys)
			ns.Print(string.format(L["Restored %d values from snapshot, %d failed"], n, failed))
			page:RunDiff(snap)
		end)
	end)

	page.scrollBox = CreateFrame("Frame", nil, page, "WowScrollBoxList")
	page.scrollBox:SetPoint("TOPLEFT", 0, diffTop - 46)
	page.scrollBox:SetPoint("BOTTOMRIGHT", -22, 2)
	page.scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
	page.scrollBar:SetPoint("TOPLEFT", page.scrollBox, "TOPRIGHT", 4, 0)
	page.scrollBar:SetPoint("BOTTOMLEFT", page.scrollBox, "BOTTOMRIGHT", 4, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_H)
	view:SetElementInitializer("Frame", function(row, item)
		if not row.built then
			row.built = true
			row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
			row.check:SetSize(18, 18)
			row.check:SetPoint("LEFT", 2, 0)
			row.check:SetScript("OnClick", function(self)
				if row.item and row.item.checkable then
					page.checked[row.item.key] = self:GetChecked() and true or nil
				end
			end)
			row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
			row.text:SetPoint("RIGHT", -4, 0)
		end
		row.item = item
		if item.header then
			row.check:Hide()
			row.text:SetPoint("LEFT", 4, 0)
			row.text:SetText("|cffffcc00" .. item.text .. "|r")
		elseif item.checkable then
			row.check:Show()
			row.check:SetChecked(page.checked[item.key] and true or false)
			row.text:SetPoint("LEFT", 26, 0)
			row.text:SetText(item.text)
		else
			row.check:Hide()
			row.text:SetPoint("LEFT", 26, 0)
			row.text:SetText(item.text)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(page.scrollBox, page.scrollBar, view)

	local function baselineCvars()
		if page.baselineIdx == 0 then
			ns.Enum:Refresh()
			return ns.Snapshots:CurrentCvars(), L["Live values"]
		end
		local s = ns.Snapshots:List()[page.baselineIdx]
		if not s then
			page.baselineIdx = 0
			ns.Enum:Refresh()
			return ns.Snapshots:CurrentCvars(), L["Live values"]
		end
		return s.cvars, s.name
	end

	function page:RunDiff(snap)
		self.diffSnap = snap
		wipe(self.checked)
		local baseCvars, baseName = baselineCvars()
		self.diff = ns.Snapshots:Diff(snap.cvars, baseCvars)
		local d = self.diff
		self.diffTitle:SetFormattedText(L["Diff %s vs %s: changed %d / added %d / removed %d / scope %d / secure %d"],
			snap.name, baseName, #d.changed, #d.added, #d.removed, #d.scopeDrift, #d.secureDrift)
		self:RenderDiff()
	end

	function page:RenderDiff()
		local d = self.diff
		if not d then return end
		local items = {}
		local function header(text, n)
			items[#items + 1] = { header = true, text = string.format("%s (%d)", text, n) }
		end
		header(L["Value changed (check to restore the snapshot value)"], #d.changed)
		for _, c in ipairs(d.changed) do
			items[#items + 1] = { key = c.key, checkable = true,
				text = c.key .. ":  " .. string.format(L["%s changed to %s"], tostring(c.from), tostring(c.to)) }
		end
		if #d.added > 0 then
			header(L["Missing in snapshot (new since then)"], #d.added)
			for _, key in ipairs(d.added) do items[#items + 1] = { text = key } end
		end
		if #d.removed > 0 then
			header(L["Only in snapshot (gone now)"], #d.removed)
			for _, key in ipairs(d.removed) do items[#items + 1] = { text = key } end
		end
		if #d.scopeDrift > 0 then
			header(L["Scope drift"], #d.scopeDrift)
			for _, c in ipairs(d.scopeDrift) do
				items[#items + 1] = { text = c.key .. ":  " .. string.format(L["%s changed to %s"], c.from, c.to) }
			end
		end
		if #d.secureDrift > 0 then
			header(L["Secure drift"], #d.secureDrift)
			for _, c in ipairs(d.secureDrift) do
				items[#items + 1] = { text = c.key .. ":  " .. string.format(L["%s changed to %s"], tostring(c.from), tostring(c.to)) }
			end
		end
		self.scrollBox:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
	end

	function page:OnPageShow()
		local list = ns.Snapshots:List()
		self.countText:SetFormattedText(L["%d / %d snapshots"], #list, ns.Snapshots.MAX)
		for _, r in ipairs(self.listRows) do r:Hide() end
		for i, snap in ipairs(list) do
			local r = listRow(i)
			r.snap = snap
			r.text:SetFormattedText("|cffffcc00%s|r   %s   build %s   %s",
				snap.name, date("%m-%d %H:%M", snap.t), tostring(snap.build),
				string.format(L["%d entries"], snap.count))
			r:Show()
		end
		refreshBaseBtn()
	end

	return page
end

ns.UI:RegisterPage("snapshot", L["Snapshots"], build)
