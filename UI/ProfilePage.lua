local ADDON, ns = ...
local L = ns.L
local Style = ns.Style

local DOMAIN_NAMES = {
	cvar = "CVar", binding = L["Keybinds"], macro = L["Macros"], editmode = "EditMode",
	clickbinding = L["Click casting"], mutesound = L["Mute list"], tts = "TTS", consoleexec = L["Console commands"],
	chatwindow = L["Chat windows"],
}
local DOMAIN_ORDER = { "cvar", "binding", "macro", "editmode", "clickbinding", "mutesound", "tts", "consoleexec", "chatwindow" }
local SCENE_NAMES = { party = L["Dungeon"], raid = L["Raid"], arena = L["Arena"], pvp = L["Battleground"], world = L["Open world"] }
local LEAVE_MODES = { "prompt", "restore", "keep" }
local LEAVE_NAMES = { prompt = L["Ask me"], restore = L["Auto fall back"], keep = L["Keep as is"] }

StaticPopupDialogs["SETTINGSHUB_PROFILE_LEAVE"] = {
	text = L["Left the auto-switch context. Return to base profile [%s]?"],
	button1 = YES, button2 = NO,
	OnAccept = function(_, base)
		ns.Profiles:Switch(base, L["context left"], true)
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["SETTINGSHUB_IMPORT_CONFIRM"] = {
	text = "%s",
	button1 = YES, button2 = NO,
	OnAccept = function(_, payload)
		ns.Profiles:ApplyImport(payload)
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["SETTINGSHUB_NEW_PROFILE"] = {
	text = L["New profile name:"],
	button1 = ACCEPT, button2 = CANCEL,
	hasEditBox = true,
	OnAccept = ns.Guard(function(self)
		local eb = ns.UI.PopupEditBox(self)
		local name = eb and eb:GetText():match("^%s*(.-)%s*$") or ""
		if name ~= "" then
			ns.Profiles:Switch(name, L["created"])
			ns.UI:Refresh()
		end
	end),
	EditBoxOnEnterPressed = ns.Guard(function(box)
		local dialog = box:GetParent()
		local b1 = (dialog.GetButton1 and dialog:GetButton1()) or dialog.button1
		if b1 then b1:Click() end
	end),
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- 循环按钮:点一下换下一个候选值
local function makeCycler(parent, width, getOptions, getCurrent, onSelect)
	local btn = ns.UI.Button(parent, "", width, 20)
	btn:SetScript("OnClick", function()
		local options = getOptions()
		local cur = getCurrent()
		local idx = 0
		for i, v in ipairs(options) do
			if v == cur then idx = i break end
		end
		onSelect(options[idx % #options + 1])
	end)
	function btn:Refresh(display)
		self:SetText(display(getCurrent()))
	end
	return btn
end

local NONE_OPTION = L["(none)"]

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)
	local refreshers = {}
	local function onShowAll()
		for _, fn in ipairs(refreshers) do fn() end
	end

	-- 左列:profile 列表与操作
	local title = Style.SectionHeader(page, "")
	title:SetPoint("TOPLEFT", 4, -2)
	refreshers[#refreshers + 1] = function()
		title:SetFormattedText(L["Active profile: |cffffcc00%s|r (character base: %s)"],
			ns.Profiles:Current(), ns.db.char.baseProfile or "Default")
	end

	local newBtn = ns.UI.Button(page, L["New/Switch"], 80, 22, true)
	newBtn:SetPoint("TOPLEFT", 0, -24)
	newBtn:SetScript("OnClick", function() StaticPopup_Show("SETTINGSHUB_NEW_PROFILE") end)

	local profileCycler
	profileCycler = makeCycler(page, 160,
		function() return ns.Profiles:List() end,
		function() return ns.Profiles:Current() end,
		function(v)
			ns.Profiles:Switch(v, L["manual switch"])
			onShowAll()
		end)
	profileCycler:SetPoint("LEFT", newBtn, "RIGHT", 8, 0)
	refreshers[#refreshers + 1] = function()
		profileCycler:Refresh(function(v) return L["Switch: "] .. tostring(v) end)
	end

	-- 域勾选 + 捕获
	local domHeader = Style.SectionHeader(page,
		L["Domains in this profile (only checked domains apply/export with it)"])
	domHeader:SetPoint("TOPLEFT", 0, -58)
	local x, checkboxes = 0, {}
	for _, d in ipairs(DOMAIN_ORDER) do
		local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
		cb:SetSize(22, 22)
		cb:SetPoint("TOPLEFT", x, -76)
		cb.label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
		cb.label:SetText(DOMAIN_NAMES[d])
		cb:SetScript("OnClick", function(self)
			ns.db.profile.domains[d] = self:GetChecked() and true or nil
		end)
		checkboxes[d] = cb
		x = x + 24 + cb.label:GetStringWidth() + 12
	end
	refreshers[#refreshers + 1] = function()
		for d, cb in pairs(checkboxes) do cb:SetChecked(ns.db.profile.domains[d] and true or false) end
	end

	local capBtn = ns.UI.Button(page, L["Capture checked domains now"], 200, 22)
	capBtn:SetPoint("TOPLEFT", 0, -104)
	capBtn:SetScript("OnClick", function()
		for _, d in ipairs(ns.Profiles.BULK_DOMAINS) do
			if ns.db.profile.domains[d] then ns.Profiles:CaptureDomain(d) end
		end
	end)
	local capHint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	capHint:SetPoint("LEFT", capBtn, "RIGHT", 8, 0)
	capHint:SetText(L["Keybinds/macros/EditMode/click casting/TTS/chat windows are snapshots: re-capture after changing them"])

	-- 四轴自动切换
	local axisHeader = Style.SectionHeader(page,
		L["Auto-switch (priority: scene > spec > resolution > character base)"])
	axisHeader:SetPoint("TOPLEFT", 0, -136)

	local function profileOptions()
		local opts = { NONE_OPTION }
		for _, p in ipairs(ns.Profiles:List()) do opts[#opts + 1] = p end
		return opts
	end
	local function axisRow(yy, labelText, getVal, setVal)
		local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("TOPLEFT", 24, yy - 4)
		label:SetText(labelText)
		local cycler
		cycler = makeCycler(page, 150, profileOptions,
			function() return getVal() or NONE_OPTION end,
			function(v)
				setVal(v ~= NONE_OPTION and v or nil)
				cycler:Refresh(tostring)
			end)
		cycler:SetPoint("TOPLEFT", 150, yy)
		refreshers[#refreshers + 1] = function() cycler:Refresh(tostring) end
		return yy - 24
	end
	local function axisEnable(yy, text, cfgKey)
		local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
		cb:SetSize(22, 22)
		cb:SetPoint("TOPLEFT", 0, yy)
		cb.label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		cb.label:SetText(text)
		cb:SetScript("OnClick", function(self)
			ns.db.global.autoSwitch[cfgKey].enabled = self:GetChecked() and true or false
			ns.Profiles:EvaluateContext()
		end)
		refreshers[#refreshers + 1] = function()
			cb:SetChecked(ns.db.global.autoSwitch[cfgKey].enabled)
		end
		return yy - 24
	end

	local yy = -156
	yy = axisEnable(yy, L["By content scene"], "scene")
	for _, scene in ipairs(ns.Profiles.SCENES) do
		yy = axisRow(yy, SCENE_NAMES[scene],
			function() return ns.db.global.autoSwitch.scene.map[scene] end,
			function(v) ns.db.global.autoSwitch.scene.map[scene] = v end)
	end
	yy = axisEnable(yy, L["By specialization"], "spec")
	if GetNumSpecializations then
		for i = 1, GetNumSpecializations() do
			local specID, specName = GetSpecializationInfo(i)
			if specID then
				yy = axisRow(yy, specName or (L["Spec"] .. " " .. i),
					function() return ns.db.global.autoSwitch.spec.map[specID] end,
					function(v) ns.db.global.autoSwitch.spec.map[specID] = v end)
			end
		end
	end
	yy = axisEnable(yy, L["By resolution"], "resolution")
	if GetPhysicalScreenSize then
		local w, h = GetPhysicalScreenSize()
		local resKey = string.format("%dx%d", w, h)
		yy = axisRow(yy, string.format(L["Current %s"], resKey),
			function() return ns.db.global.autoSwitch.resolution.map[resKey] end,
			function(v) ns.db.global.autoSwitch.resolution.map[resKey] = v end)
	end

	local leaveLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	leaveLabel:SetPoint("TOPLEFT", 0, yy - 8)
	leaveLabel:SetText(L["When leaving a context"])
	local leaveCycler
	leaveCycler = makeCycler(page, 110,
		function() return LEAVE_MODES end,
		function() return ns.db.global.autoSwitch.onLeave end,
		function(v)
			ns.db.global.autoSwitch.onLeave = v
			leaveCycler:Refresh(function(x) return LEAVE_NAMES[x] end)
		end)
	leaveCycler:SetPoint("TOPLEFT", 150, yy - 4)
	refreshers[#refreshers + 1] = function()
		leaveCycler:Refresh(function(x) return LEAVE_NAMES[x] end)
	end
	yy = yy - 36

	-- 导入导出
	local exportBtn = ns.UI.Button(page, L["Export string"], 100, 22)
	exportBtn:SetPoint("TOPLEFT", 0, yy)
	exportBtn:SetScript("OnClick", function()
		StaticPopup_Show("SETTINGSHUB_COPY", nil, nil, ns.Profiles:Export())
	end)

	-- 遗留:导入串输入与本页 UICheckButtonTemplate 按任务卡保留。
	local importBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	importBox:SetSize(320, 20)
	importBox:SetPoint("LEFT", exportBtn, "RIGHT", 16, 0)
	importBox:SetAutoFocus(false)
	local importBtn = ns.UI.Button(page, L["Preview & import"], 110, 22, true)
	importBtn:SetPoint("LEFT", importBox, "RIGHT", 8, 0)
	importBtn:SetScript("OnClick", function()
		local payload, err = ns.Profiles:Decode(importBox:GetText())
		if not payload then
			ns.Print(L["Invalid import string: "] .. tostring(err))
			return
		end
		local changes, bulk, unknown = ns.Profiles:DiffAgainstCurrent(payload)
		for i, c in ipairs(changes) do
			if i <= 30 then
				ns.Print(string.format(L["  %s: %s changed to %s"], c.key, c.old, c.new))
			end
		end
		if #changes > 30 then ns.Print(string.format(L["  ...%d in total, rest omitted"], #changes)) end
		local summary = string.format(
			L["Import [%s] (%s): %d per-value changes (details in chat)%s%s. Apply?"],
			tostring(payload.name), tostring(payload.game), #changes,
			#bulk > 0 and (L[", full-domain replace: "] .. table.concat(bulk, "/")) or "",
			unknown > 0 and (string.format(L[", %d unknown on this client will be skipped"], unknown)) or "")
		StaticPopup_Show("SETTINGSHUB_IMPORT_CONFIRM", summary, nil, payload)
	end)

	function page:OnPageShow()
		onShowAll()
	end

	return page
end

ns.UI:RegisterPage("profile", L["Profiles & Migration"], build)
