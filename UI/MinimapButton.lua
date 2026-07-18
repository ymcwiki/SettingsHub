local ADDON, ns = ...
local L = ns.L

-- v0.4 小地图按钮:手搓不引 LibDBIcon(零新依赖),沿小地图边缘拖动定位,角度存 SV
local RADIUS = 105

local btn = CreateFrame("Button", "SettingsHubMinimapButton", Minimap)
btn:SetSize(32, 32)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("LeftButtonUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", -1, 1)
icon:SetTexture("Interface\\AddOns\\SettingsHub\\Media\\icon.png")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function angle()
	return ns.db and ns.db.global.minimap and ns.db.global.minimap.angle or 220
end

local function reposition()
	local rad = math.rad(angle())
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * RADIUS, math.sin(rad) * RADIUS)
end

btn:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		local deg = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
		if ns.db then ns.db.global.minimap.angle = deg end
		reposition()
	end)
end)
btn:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)
btn:SetScript("OnClick", ns.Guard(function()
	ns.UI:Toggle()
end))
btn:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("SettingsHub", 1, 1, 1)
	GameTooltip:AddLine(L["Click to open; drag to move around the minimap"], 0.8, 0.8, 0.8)
	GameTooltip:Show()
end)
btn:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- db 就绪后按存档角度定位(文件加载时 db 未必已初始化)
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
	reposition()
end)
reposition()
