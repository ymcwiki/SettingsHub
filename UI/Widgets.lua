local ADDON, ns = ...
local L = ns.L
local G = ns.Guard

local W = {}
ns.Widgets = W

-- requiresReload 项改动后进 pending 集(会话级,重载后自然清空),ThemePage 据此显示重载按钮
ns.Pending = ns.Pending or {}

local LABEL_W = 430
local CTRL_X = 450

local function trimNum(v)
	local s = tostring(v or "")
	if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
	return s
end

local function curValue(control)
	local adapter = ns.Adapters[control.domain]
	if not adapter then return nil end
	return adapter:Read(control.key)
end

local function setValue(control, v)
	local r, err = ns.Engine:Set(control.domain, control.key, v, "user")
	if r == "failed" then
		ns.Print(string.format(L["%s write failed (%s)"], control.key, tostring(err)))
	elseif r == "queued" then
		ns.Print(string.format(L["%s queued during combat, applies when combat ends"], control.key))
	elseif r == "applied" and control.requiresReload then
		ns.Pending[control.id] = true
	end
	ns.UI:Refresh()
	return r
end

local SCOPE_NAMES = { account = L["Account"], character = L["Character"], machine = L["Machine"] }

local function controlTooltip(owner, control)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(control.key or control.id, 1, 1, 1)
	local desc = ns.ControlText(control)
	if desc ~= "" then
		GameTooltip:AddLine(desc, 0.9, 0.9, 0.6, true)
	end
	if control.domain == "cvar" and control.key then
		local info = ns.Enum:Get(control.key)
		if info then
			GameTooltip:AddDoubleLine(L["Current"], tostring(info.value), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine(L["Default"], tostring(info.default), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine(L["Scope"], SCOPE_NAMES[info.scope] or info.scope, 0.8, 0.8, 0.8, 1, 1, 1)
			local blame = ns.Blame:Get(control.key)
			if blame then
				GameTooltip:AddDoubleLine(L["Last write"], string.format("%s(%s)", blame.by, date("%m-%d %H:%M", blame.t)),
					0.8, 0.8, 0.8, 1, 0.7, 0.3)
			end
		end
	end
	if control.noReadback then
		GameTooltip:AddLine(L["No readback: recorded as desired state and replayed at login"], 1, 0.6, 0.3, true)
	end
	if control.secure then
		GameTooltip:AddLine(L["Combat-locked: the client blocks changes in combat, writes queue until combat ends"], 1, 0.4, 0.4, true)
	end
	if control.requiresReload then GameTooltip:AddLine(L["Takes effect after /reload"], 1, 0.8, 0, true) end
	if control.requiresRestart then GameTooltip:AddLine(L["Takes effect after a game restart"], 1, 0.6, 0, true) end
	local v = control.version
	if v and v.added then
		GameTooltip:AddDoubleLine(L["Added in"], v.added, 0.8, 0.8, 0.8, 0.6, 0.9, 1)
	end
	if v and v.changed then
		for _, ch in ipairs(v.changed) do
			GameTooltip:AddLine(string.format("%s:%s", ch.patch, ch.note), 0.6, 0.9, 1, true)
		end
	end
	GameTooltip:Show()
end

local function attachTooltip(f, control)
	f:SetScript("OnEnter", G(function(self) controlTooltip(self, control) end))
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function labelText(control)
	local head = ns.ControlLabel(control)
	local marks = {}
	if control.secure then marks[#marks + 1] = "|cffff5555" .. L["Secure"] .. "|r" end
	if control.requiresReload then marks[#marks + 1] = "|cffffcc00" .. L["Reload"] .. "|r" end
	if control.requiresRestart then marks[#marks + 1] = "|cffff8800" .. L["Restart"] .. "|r" end
	local vv = control.version
	if vv and vv.added and vv.added:find("^12%.1") then marks[#marks + 1] = "|cff66ccff" .. L["12.1 New"] .. "|r" end
	return head .. (#marks > 0 and ("  " .. table.concat(marks, " ")) or "")
end

local function baseRow(parent, control, height)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(parent:GetWidth() > 0 and parent:GetWidth() or 800, height)
	f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.label:SetPoint("LEFT", 4, 0)
	f.label:SetWidth(LABEL_W)
	f.label:SetJustifyH("LEFT")
	f.label:SetWordWrap(false)
	f:EnableMouse(true)
	local hl = f:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.05)
	attachTooltip(f, control)
	return f
end

local function markModified(f, control)
	local modified = false
	if control.domain == "cvar" and control.key then
		local info = ns.Enum:Get(control.key)
		modified = info and info.value ~= info.default
	end
	local pending = ns.Pending[control.id] and ("  |cffffcc00" .. L["Pending reload"] .. "|r") or ""
	f.label:SetText((modified and "|cffff9922*|r " or "") .. labelText(control) .. pending)
	local locked = control.secure and ns.UI.combatLocked
	f:SetAlpha(locked and 0.4 or 1)
	return locked
end

local builders = {}

function builders.bool(parent, control)
	local f = baseRow(parent, control, 26)
	f.check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	f.check:SetSize(24, 24)
	f.check:SetPoint("LEFT", CTRL_X, 0)
	f.check:SetScript("OnClick", G(function(self)
		setValue(control, self:GetChecked() and "1" or "0")
	end))
	attachTooltip(f.check, control)
	function f:Update()
		local locked = markModified(self, control)
		local v = tonumber(curValue(control))
		self.check:SetChecked(v ~= nil and v ~= 0)
		self.check:SetEnabled(not locked)
	end
	return f
end

local function editBuilder(parent, control)
	local f = baseRow(parent, control, 28)
	f.edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.edit:SetSize(96, 20)
	f.edit:SetPoint("LEFT", CTRL_X + 4, 0)
	f.edit:SetAutoFocus(false)
	f.edit:SetScript("OnEnterPressed", G(function(self)
		setValue(control, self:GetText())
		self:ClearFocus()
	end))
	f.edit:SetScript("OnEscapePressed", function(self)
		self:SetText(trimNum(curValue(control)))
		self:ClearFocus()
	end)
	function f:Update()
		local locked = markModified(self, control)
		if not self.edit:HasFocus() then
			self.edit:SetText(trimNum(curValue(control)))
		end
		self.edit:SetEnabled(not locked)
	end
	return f
end
builders.string = editBuilder

-- 带范围的数值项用真滑块(v0.4 手感升级):拖动实时显示,松手一次性提交(不刷爆撤销日志);
-- 旁边保留精确输入框。无范围数值项退回输入框
local function sliderBuilder(parent, control)
	local f = baseRow(parent, control, 30)
	local lo, hi, step = control.range[1], control.range[2], control.range[3] or 1
	f.slider = CreateFrame("Slider", nil, f)
	f.slider:SetOrientation("HORIZONTAL")
	f.slider:SetSize(150, 16)
	f.slider:SetPoint("LEFT", CTRL_X, 0)
	f.slider:SetMinMaxValues(lo, hi)
	f.slider:SetValueStep(step)
	f.slider:SetObeyStepOnDrag(true)
	f.slider:EnableMouse(true)
	local track = f.slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT", 0, 0)
	track:SetPoint("RIGHT", 0, 0)
	track:SetHeight(4)
	track:SetColorTexture(0.4, 0.45, 0.55, 0.5)
	f.slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local thumb = f.slider:GetThumbTexture()
	if thumb then thumb:SetSize(24, 24) end

	f.edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.edit:SetSize(56, 20)
	f.edit:SetPoint("LEFT", f.slider, "RIGHT", 14, 0)
	f.edit:SetAutoFocus(false)
	f.edit:SetScript("OnEnterPressed", G(function(self)
		setValue(control, self:GetText())
		self:ClearFocus()
	end))
	f.edit:SetScript("OnEscapePressed", function(self)
		self:SetText(trimNum(curValue(control)))
		self:ClearFocus()
	end)

	f.slider:SetScript("OnValueChanged", function(self, v, userInput)
		if userInput then
			f.edit:SetText(trimNum(v))
		end
	end)
	f.slider:SetScript("OnMouseUp", G(function(self)
		setValue(control, trimNum(self:GetValue()))
	end))
	attachTooltip(f.slider, control)
	function f:Update()
		local locked = markModified(self, control)
		local v = tonumber(curValue(control))
		if v then f.slider:SetValue(v) end
		if not self.edit:HasFocus() then
			self.edit:SetText(trimNum(curValue(control)))
		end
		f.slider:SetEnabled(not locked)
		self.edit:SetEnabled(not locked)
	end
	return f
end

function builders.number(parent, control)
	if control.range then
		return sliderBuilder(parent, control)
	end
	return editBuilder(parent, control)
end

-- 枚举项用现代下拉菜单(11.x DropdownButton),环境不支持时退回循环按钮
function builders.enum(parent, control)
	local f = baseRow(parent, control, 28)
	local function display(v)
		local label = control.valueLabels and control.valueLabels[tostring(v)]
		return label and string.format("%s(%s)", L[label], tostring(v)) or tostring(v)
	end
	local hasDropdown = MenuUtil and pcall(function()
		f.btn = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
	end)
	if hasDropdown and f.btn then
		f.btn:SetSize(150, 24)
		f.btn:SetPoint("LEFT", CTRL_X, 0)
		f.btn:SetupMenu(function(_, root)
			for _, v in ipairs(control.values) do
				root:CreateRadio(display(v),
					function() return tostring(curValue(control)) == tostring(v) end,
					G(function() setValue(control, v) end))
			end
		end)
		function f:Update()
			local locked = markModified(self, control)
			if f.btn.OverrideText then
				f.btn:OverrideText(display(curValue(control) or "?"))
			end
			f.btn:SetEnabled(not locked)
		end
	else
		f.btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		f.btn:SetSize(110, 22)
		f.btn:SetPoint("LEFT", CTRL_X, 0)
		f.btn:SetScript("OnClick", G(function()
			local cur = tostring(curValue(control) or control.values[1])
			local idx = 1
			for i, v in ipairs(control.values) do
				if tostring(v) == cur then idx = i break end
			end
			setValue(control, control.values[idx % #control.values + 1])
		end))
		function f:Update()
			local locked = markModified(self, control)
			f.btn:SetText(display(curValue(control) or "?"))
			f.btn:SetEnabled(not locked)
		end
	end
	attachTooltip(f.btn, control)
	return f
end

StaticPopupDialogs["SETTINGSHUB_ACTION_CONFIRM"] = {
	text = L["Run: %s?"],
	button1 = YES, button2 = NO,
	OnAccept = function(self, run)
		if ns.Actions[run] then ns.Actions[run]() end
		ns.UI:Refresh()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function builders.action(parent, control)
	local f = baseRow(parent, control, 30)
	f.btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.btn:SetSize(150, 24)
	f.btn:SetPoint("LEFT", CTRL_X, 0)
	f.btn:SetText(control.buttonText and L[control.buttonText] or L["Run"])
	f.btn:SetScript("OnClick", G(function()
		if control.confirm then
			StaticPopup_Show("SETTINGSHUB_ACTION_CONFIRM",
				control.buttonText and L[control.buttonText] or control.id, nil, control.run)
		else
			if ns.Actions[control.run] then ns.Actions[control.run]() end
			ns.UI:Refresh()
		end
	end))
	attachTooltip(f.btn, control)
	function f:Update()
		markModified(self, control)
	end
	return f
end

function builders.composite(parent, control)
	local f = CreateFrame("Frame", nil, parent)
	local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOPLEFT", 4, -4)
	header:SetText(labelText(control))
	f:EnableMouse(true)
	attachTooltip(f, control)
	f.children = {}
	local y = -26
	for _, child in ipairs(control.children or {}) do
		local missing = child.domain == "cvar" and child.key and not ns.Enum:Get(child.key)
		if not child.verify and not missing then
			local cw = W.Create(f, child)
			if cw then
				cw:SetPoint("TOPLEFT", 16, y)
				cw:SetWidth(780)
				y = y - cw:GetHeight()
				f.children[#f.children + 1] = cw
			end
		end
	end
	f:SetSize(800, -y + 6)
	function f:Update()
		for _, cw in ipairs(self.children) do cw:Update() end
	end
	return f
end

function W.Create(parent, control)
	local builder = builders[control.type]
	if not builder then return nil end
	return builder(parent, control)
end
