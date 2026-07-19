local ADDON, ns = ...

-- UI 视觉骨架集中在这里；后续换肤只改本文件，不让页面散落配色与尺寸。
local S = {
	FrameWidth = 1000,
	FrameHeight = 640,
	NavWidth = 150,
	NavRowHeight = 20,
	NavGap = 1,
	NavSeparatorGap = 6,
	SearchWidth = 280,
	SearchHeight = 22,

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

	Backdrop = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	},
	Colors = {
		Transparent = { 0, 0, 0, 0 },
		PanelBackground = { 0.08, 0.08, 0.1, 0.98 },
		PanelBorder = { 0.55, 0.55, 0.6, 1 },
		NavText = { 0.9, 0.9, 0.9, 1 },
		NavSelectedText = { 1, 0.82, 0, 1 },
		NavSelectedBackground = { 1, 0.82, 0, 0.09 },
		NavHover = { 1, 1, 1, 0.08 },
		Separator = { 0.45, 0.45, 0.5, 0.55 },
		Combat = { 1, 0.3, 0.3, 1 },
		RowHover = { 1, 1, 1, 0.06 },
		Favorite = { 1, 0.82, 0.15, 1 },
		Unfavorite = { 0.55, 0.55, 0.55, 1 },
		Modified = { 1, 0.6, 0.1, 1 },
		NormalValue = { 1, 1, 1, 1 },
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

function S.Panel(frame)
	frame:SetBackdrop(S.Backdrop)
	setColor(frame, "SetBackdropColor", S.Colors.PanelBackground)
	setColor(frame, "SetBackdropBorderColor", S.Colors.PanelBorder)
	return frame
end

function S.NavRow(btn, selected)
	local textColor = selected and S.Colors.NavSelectedText or S.Colors.NavText
	setColor(btn.text, "SetTextColor", textColor)
	if not btn.styleBackground then
		btn.styleBackground = btn:CreateTexture(nil, "BACKGROUND")
		btn.styleBackground:SetAllPoints()
	end
	local bg = selected and S.Colors.NavSelectedBackground or S.Colors.Transparent
	setColor(btn.styleBackground, "SetColorTexture", bg)
end

function S.Separator(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(S.SeparatorHeight)
	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetAllPoints()
	setColor(line, "SetColorTexture", S.Colors.Separator)
	return frame
end
