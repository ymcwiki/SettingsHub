local ADDON, ns = ...

-- 视觉令牌与自绘控件集中于此。页面只负责布局和行为，不散落颜色或皮肤尺寸。
local S = {
	Texture = "Interface\\Buttons\\WHITE8x8",
	FrameWidth = 1000,
	FrameHeight = 680,
	TitleBarHeight = 40,
	TitleInset = 16,
	CloseButtonSize = 20,
	FrameInset = 12,
	NavTop = 40,
	NavWidth = 150,
	NavRowHeight = 20,
	NavGap = 1,
	NavSeparatorGap = 8,
	NavTextInset = 8,
	NavSelectedBarWidth = 3,
	SearchWidth = 280,
	SearchHeight = 22,
	SearchTextInset = 8,
	SearchHintGap = 10,
	CombatPaddingX = 8,
	CombatPaddingY = 3,

	ListRowHeight = 24,
	ListHeaderHeight = 18,
	ListScrollBarGap = 4,
	ListScrollBarReserve = 22,
	ListColumnGap = 6,
	ListNameInset = 22,
	FavoriteButtonSize = 18,
	ListColumns = { name = 0, value = 320, default = 445, scope = 570, flags = 630 },
	EditorWidth = 110,
	EditorHeight = 20,
	CopyEditWidth = 320,

	CuratedMaxHeight = 210,
	CuratedContentWidth = 800,
	SectionHeaderHeight = 22,
	SectionLineGap = 8,
	SeparatorHeight = 1,
	NoteHeight = 18,
	ReloadButtonWidth = 120,
	ReloadButtonHeight = 22,
	SoundMuteHeight = 116,
	MuteInputWidth = 120,
	MuteInputHeight = 20,
	MuteAddWidth = 60,
	MuteAddHeight = 22,
	MuteRowWidth = 500,
	MuteRowHeight = 22,
	MuteRowStep = 24,
	MuteTempWidth = 76,
	MuteTempHeight = 18,
	MuteRemoveWidth = 50,
	MuteRemoveHeight = 18,
	CardInset = 8,

	Backdrop = {
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false, edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	},
	Colors = {
		Transparent = { 0, 0, 0, 0 },
		PanelBackground = { 20 / 255, 21 / 255, 23 / 255, 0.97 },
		PanelBorder = { 42 / 255, 44 / 255, 48 / 255, 1 },
		NavBackground = { 15 / 255, 16 / 255, 18 / 255, 1 },
		PrimaryText = { 242 / 255, 242 / 255, 242 / 255, 1 },
		SecondaryText = { 154 / 255, 160 / 255, 166 / 255, 1 },
		DisabledText = { 107 / 255, 112 / 255, 117 / 255, 1 },
		Accent = { 1, 199 / 255, 61 / 255, 1 },
		AccentHover = { 1, 209 / 255, 92 / 255, 1 },
		DeepText = { 20 / 255, 21 / 255, 23 / 255, 1 },
		NavText = { 242 / 255, 242 / 255, 242 / 255, 1 },
		NavSelectedText = { 1, 199 / 255, 61 / 255, 1 },
		NavSelectedBackground = { 1, 1, 1, 0.06 },
		NavHover = { 1, 1, 1, 0.04 },
		Separator = { 42 / 255, 44 / 255, 48 / 255, 1 },
		CombatBackground = { 1, 199 / 255, 61 / 255, 0.15 },
		Combat = { 1, 199 / 255, 61 / 255, 1 },
		SearchBackground = { 28 / 255, 30 / 255, 34 / 255, 1 },
		ButtonBackground = { 38 / 255, 40 / 255, 44 / 255, 1 },
		ButtonBorder = { 52 / 255, 55 / 255, 60 / 255, 1 },
		ButtonHover = { 46 / 255, 49 / 255, 54 / 255, 1 },
		ButtonPressed = { 1, 1, 1, 0.10 },
		RowStripe = { 1, 1, 1, 0.02 },
		RowHover = { 1, 1, 1, 0.06 },
		CardBackground = { 1, 1, 1, 0.03 },
		Favorite = { 1, 0.82, 0.15, 1 },
		Unfavorite = { 0.55, 0.55, 0.55, 1 },
		Modified = { 1, 0.6, 0.1, 1 },
		NormalValue = { 242 / 255, 242 / 255, 242 / 255, 1 },
		Error = { 1, 0.3, 0.3, 1 },
		TooltipTitle = { 1, 1, 1 },
		TooltipDescription = { 0.9, 0.9, 0.6 },
		TooltipMuted = { 0.6, 0.6, 0.6 },
		TooltipLabel = { 0.8, 0.8, 0.8 },
		TooltipValue = { 1, 1, 1 },
		TooltipAccent = { 1, 0.7, 0.3 },
		TooltipVersion = { 0.6, 0.9, 1 },
		TooltipVerified = { 1, 0.82, 0.15 },
		TooltipUnverified = { 0.55, 0.55, 0.55 },
		TooltipWarning = { 1, 0.53, 0 },
	},
	Markup = {
		Account = "|cff4da6ff",
		Character = "|cff66cc66",
		Machine = "|cff999999",
		Secure = "|cffff5555",
		Disabled = "|cff888888",
		Reload = "|cffffcc00",
		Restart = "|cffff8800",
		Warning = "|cffff8800",
		Curated = "|cffffcc00",
		Close = "|r",
	},
}
ns.Style = S

local function setColor(target, method, color)
	target[method](target, color[1], color[2], color[3], color[4])
end
S.SetColor = setColor

function S.Panel(frame)
	frame:SetBackdrop(S.Backdrop)
	setColor(frame, "SetBackdropColor", S.Colors.PanelBackground)
	setColor(frame, "SetBackdropBorderColor", S.Colors.PanelBorder)
	return frame
end

function S.Fill(parent, layer, color)
	local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetTexture(S.Texture)
	setColor(texture, "SetVertexColor", color)
	return texture
end

function S.NavRow(btn, selected)
	setColor(btn.text, "SetTextColor", selected and S.Colors.NavSelectedText or S.Colors.NavText)
	if not btn.styleBackground then
		btn.styleBackground = S.Fill(btn, "BACKGROUND", S.Colors.Transparent)
		btn.styleBackground:SetAllPoints()
		btn.selectedBar = S.Fill(btn, "ARTWORK", S.Colors.Accent)
		btn.selectedBar:SetPoint("TOPLEFT")
		btn.selectedBar:SetPoint("BOTTOMLEFT")
		btn.selectedBar:SetWidth(S.NavSelectedBarWidth)
	end
	setColor(btn.styleBackground, "SetVertexColor",
		selected and S.Colors.NavSelectedBackground or S.Colors.Transparent)
	btn.selectedBar:SetShown(selected)
end

function S.Separator(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(S.SeparatorHeight)
	local line = S.Fill(frame, "ARTWORK", S.Colors.Separator)
	line:SetAllPoints()
	return frame
end

function S.SectionHeader(parent, text)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetText(text or "")
	setColor(label, "SetTextColor", S.Colors.SecondaryText)
	local line = S.Fill(parent, "ARTWORK", S.Colors.Separator)
	line:SetPoint("LEFT", label, "RIGHT", S.SectionLineGap, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	line:SetHeight(S.SeparatorHeight)
	return label, line
end

function S.Card(frame)
	frame:SetBackdrop(S.Backdrop)
	setColor(frame, "SetBackdropColor", S.Colors.CardBackground)
	setColor(frame, "SetBackdropBorderColor", S.Colors.PanelBorder)
	return frame
end

function S.ListRow(row, even)
	if not row.styleStripe then
		row.styleStripe = S.Fill(row, "BACKGROUND", S.Colors.Transparent)
		row.styleStripe:SetAllPoints()
	end
	setColor(row.styleStripe, "SetVertexColor", even and S.Colors.RowStripe or S.Colors.Transparent)
end

local function buttonVisual(btn, hover)
	local enabled = not btn.IsEnabled or btn:IsEnabled()
	local bg = btn.primary and S.Colors.Accent or (hover and S.Colors.ButtonHover or S.Colors.ButtonBackground)
	if btn.primary and hover then bg = S.Colors.AccentHover end
	setColor(btn, "SetBackdropColor", bg)
	setColor(btn, "SetBackdropBorderColor", S.Colors.ButtonBorder)
	setColor(btn.text, "SetTextColor", enabled
		and (btn.primary and S.Colors.DeepText or S.Colors.PrimaryText) or S.Colors.DisabledText)
end

-- 全部普通页面动作使用该工厂。StaticPopup、复选框、滑块、下拉和行内输入保留原模板。
function ns.UI.Button(parent, text, width, height, primary)
	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	btn:SetSize(width, height)
	btn:SetBackdrop(S.Backdrop)
	btn.primary = primary and true or false
	btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	btn.text:SetPoint("CENTER")
	btn.text:SetText(text or "")
	btn.SetText = function(self, value) self.text:SetText(value or "") end
	btn.GetText = function(self) return self.text:GetText() end
	btn.pressed = S.Fill(btn, "ARTWORK", S.Colors.ButtonPressed)
	btn.pressed:SetAllPoints()
	btn.pressed:Hide()
	-- 用 HookScript 保留页面后续挂载的 tooltip/行为脚本。
	btn:HookScript("OnEnter", function(self) buttonVisual(self, true) end)
	btn:HookScript("OnLeave", function(self) self.pressed:Hide(); buttonVisual(self, false) end)
	btn:HookScript("OnMouseDown", function(self) if self:IsEnabled() then self.pressed:Show() end end)
	btn:HookScript("OnMouseUp", function(self) self.pressed:Hide(); buttonVisual(self, self:IsMouseOver()) end)
	btn:HookScript("OnEnable", function(self) buttonVisual(self, false) end)
	btn:HookScript("OnDisable", function(self) buttonVisual(self, false) end)
	buttonVisual(btn, false)
	return btn
end

function S.CloseButton(parent)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(S.CloseButtonSize, S.CloseButtonSize)
	btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	btn.text:SetPoint("CENTER", 0, 1)
	btn.text:SetText("×")
	setColor(btn.text, "SetTextColor", S.Colors.SecondaryText)
	btn:SetScript("OnEnter", function(self) setColor(self.text, "SetTextColor", S.Colors.Accent) end)
	btn:SetScript("OnLeave", function(self) setColor(self.text, "SetTextColor", S.Colors.SecondaryText) end)
	btn:SetScript("OnClick", function() parent:Hide() end)
	return btn
end

function S.SearchBox(parent, placeholder)
	local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	box:SetSize(S.SearchWidth, S.SearchHeight)
	box:SetBackdrop(S.Backdrop)
	setColor(box, "SetBackdropColor", S.Colors.SearchBackground)
	setColor(box, "SetBackdropBorderColor", S.Colors.ButtonBorder)
	box:SetFontObject("GameFontHighlightSmall")
	box:SetTextInsets(S.SearchTextInset, S.SearchTextInset, 0, 0)
	box:SetAutoFocus(false)
	box.placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	box.placeholder:SetPoint("LEFT", S.SearchTextInset, 0)
	box.placeholder:SetText(placeholder)
	setColor(box.placeholder, "SetTextColor", S.Colors.SecondaryText)
	box:HookScript("OnTextChanged", function(self) self.placeholder:SetShown(self:GetText() == "") end)
	box:HookScript("OnEditFocusGained", function(self)
		setColor(self, "SetBackdropBorderColor", S.Colors.Accent)
	end)
	box:HookScript("OnEditFocusLost", function(self)
		setColor(self, "SetBackdropBorderColor", S.Colors.ButtonBorder)
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return box
end
