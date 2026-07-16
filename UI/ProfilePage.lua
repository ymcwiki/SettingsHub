local ADDON, ns = ...

local DOMAIN_NAMES = {
	cvar = "CVar", binding = "键位", macro = "宏", editmode = "EditMode",
	clickbinding = "点击施法", mutesound = "静音列表", tts = "TTS", consoleexec = "console 命令",
}
local DOMAIN_ORDER = { "cvar", "binding", "macro", "editmode", "clickbinding", "mutesound", "tts", "consoleexec" }
local SCENE_NAMES = { party = "地城", raid = "团本", arena = "竞技场", pvp = "战场", world = "野外" }
local LEAVE_MODES = { "prompt", "restore", "keep" }
local LEAVE_NAMES = { prompt = "提示我", restore = "自动回落", keep = "保持不动" }

StaticPopupDialogs["SETTINGSHUB_PROFILE_LEAVE"] = {
	text = "已离开自动切换的上下文,回到基准 profile [%s]?",
	button1 = YES, button2 = NO,
	OnAccept = function(_, base)
		ns.Profiles:Switch(base, "上下文退出", true)
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
	text = "新 profile 名字:",
	button1 = ACCEPT, button2 = CANCEL,
	hasEditBox = true,
	OnAccept = function(self)
		local name = self.editBox:GetText():match("^%s*(.-)%s*$")
		if name ~= "" then
			ns.Profiles:Switch(name, "新建")
			ns.UI:Refresh()
		end
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- 循环按钮:点一下换下一个候选值
local function makeCycler(parent, width, getOptions, getCurrent, onSelect)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width, 20)
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

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)
	local refreshers = {}
	local function onShowAll()
		for _, fn in ipairs(refreshers) do fn() end
	end

	-- 左列:profile 列表与操作
	local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 4, -2)
	refreshers[#refreshers + 1] = function()
		title:SetFormattedText("当前 profile: |cffffcc00%s|r(角色基准: %s)",
			ns.Profiles:Current(), ns.db.char.baseProfile or "Default")
	end

	local newBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	newBtn:SetSize(80, 22)
	newBtn:SetPoint("TOPLEFT", 0, -24)
	newBtn:SetText("新建/切换")
	newBtn:SetScript("OnClick", function() StaticPopup_Show("SETTINGSHUB_NEW_PROFILE") end)

	local profileCycler
	profileCycler = makeCycler(page, 160,
		function() return ns.Profiles:List() end,
		function() return ns.Profiles:Current() end,
		function(v)
			ns.Profiles:Switch(v, "手动切换")
			onShowAll()
		end)
	profileCycler:SetPoint("LEFT", newBtn, "RIGHT", 8, 0)
	refreshers[#refreshers + 1] = function()
		profileCycler:Refresh(function(v) return "切换: " .. tostring(v) end)
	end

	-- 域勾选 + 捕获
	local domHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	domHeader:SetPoint("TOPLEFT", 0, -58)
	domHeader:SetText("本 profile 收录的域(勾选后才随 profile 应用/导出)")
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

	local capBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	capBtn:SetSize(200, 22)
	capBtn:SetPoint("TOPLEFT", 0, -104)
	capBtn:SetText("捕获勾选域的当前状态")
	capBtn:SetScript("OnClick", function()
		for _, d in ipairs(ns.Profiles.BULK_DOMAINS) do
			if ns.db.profile.domains[d] then ns.Profiles:CaptureDomain(d) end
		end
	end)
	local capHint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	capHint:SetPoint("LEFT", capBtn, "RIGHT", 8, 0)
	capHint:SetText("键位/宏/EditMode/点击施法/TTS 是快照式,改完要重新捕获")

	-- 四轴自动切换
	local axisHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	axisHeader:SetPoint("TOPLEFT", 0, -136)
	axisHeader:SetText("自动切换(优先级:场景 > 专精 > 分辨率 > 角色基准)")

	local function profileOptions()
		local opts = { "(无)" }
		for _, p in ipairs(ns.Profiles:List()) do opts[#opts + 1] = p end
		return opts
	end
	local function axisRow(yy, labelText, getVal, setVal)
		local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("TOPLEFT", 24, yy - 4)
		label:SetText(labelText)
		local cycler
		cycler = makeCycler(page, 150, profileOptions,
			function() return getVal() or "(无)" end,
			function(v)
				setVal(v ~= "(无)" and v or nil)
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
	yy = axisEnable(yy, "按内容场景", "scene")
	for _, scene in ipairs(ns.Profiles.SCENES) do
		yy = axisRow(yy, SCENE_NAMES[scene],
			function() return ns.db.global.autoSwitch.scene.map[scene] end,
			function(v) ns.db.global.autoSwitch.scene.map[scene] = v end)
	end
	yy = axisEnable(yy, "按专精", "spec")
	if GetNumSpecializations then
		for i = 1, GetNumSpecializations() do
			local specID, specName = GetSpecializationInfo(i)
			if specID then
				yy = axisRow(yy, specName or ("专精 " .. i),
					function() return ns.db.global.autoSwitch.spec.map[specID] end,
					function(v) ns.db.global.autoSwitch.spec.map[specID] = v end)
			end
		end
	end
	yy = axisEnable(yy, "按分辨率", "resolution")
	if GetPhysicalScreenSize then
		local w, h = GetPhysicalScreenSize()
		local resKey = string.format("%dx%d", w, h)
		yy = axisRow(yy, "当前 " .. resKey,
			function() return ns.db.global.autoSwitch.resolution.map[resKey] end,
			function(v) ns.db.global.autoSwitch.resolution.map[resKey] = v end)
	end

	local leaveLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	leaveLabel:SetPoint("TOPLEFT", 0, yy - 8)
	leaveLabel:SetText("离开上下文时")
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
	local exportBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	exportBtn:SetSize(100, 22)
	exportBtn:SetPoint("TOPLEFT", 0, yy)
	exportBtn:SetText("导出分享串")
	exportBtn:SetScript("OnClick", function()
		StaticPopup_Show("SETTINGSHUB_COPY", nil, nil, ns.Profiles:Export())
	end)

	local importBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	importBox:SetSize(320, 20)
	importBox:SetPoint("LEFT", exportBtn, "RIGHT", 16, 0)
	importBox:SetAutoFocus(false)
	local importBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	importBtn:SetSize(110, 22)
	importBtn:SetPoint("LEFT", importBox, "RIGHT", 8, 0)
	importBtn:SetText("预览并导入")
	importBtn:SetScript("OnClick", function()
		local payload, err = ns.Profiles:Decode(importBox:GetText())
		if not payload then
			ns.Print("导入串无效:" .. tostring(err))
			return
		end
		local changes, bulk, unknown = ns.Profiles:DiffAgainstCurrent(payload)
		for i, c in ipairs(changes) do
			if i <= 30 then
				ns.Print(string.format("  %s: %s 改为 %s", c.key, c.old, c.new))
			end
		end
		if #changes > 30 then ns.Print(string.format("  ……共 %d 项,余下略", #changes)) end
		local summary = string.format(
			"导入 [%s](%s):%d 项逐条改动(明细见聊天框)%s%s。应用?",
			tostring(payload.name), tostring(payload.game), #changes,
			#bulk > 0 and (",整域替换: " .. table.concat(bulk, "/")) or "",
			unknown > 0 and (string.format(",%d 项本客户端不识别将跳过", unknown)) or "")
		StaticPopup_Show("SETTINGSHUB_IMPORT_CONFIRM", summary, nil, payload)
	end)

	function page:OnPageShow()
		onShowAll()
	end

	return page
end

ns.UI:RegisterPage("profile", "Profile 与迁移", build)
