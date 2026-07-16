local ADDON, ns = ...

local function buildThemePage(theme)
	return function(parent)
		local page = CreateFrame("Frame", nil, parent)

		local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 0, -4)
		scroll:SetPoint("BOTTOMRIGHT", -28, 30)
		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(800, 10)
		scroll:SetScrollChild(content)

		page.widgets = {}
		local y, hiddenCount = 0, 0
		for _, control in ipairs(theme.controls) do
			if control.verify then
				hiddenCount = hiddenCount + 1
			else
				local w = ns.Widgets.Create(content, control)
				if w then
					w:SetPoint("TOPLEFT", 0, y)
					w:SetWidth(800)
					y = y - w:GetHeight() - 2
					page.widgets[#page.widgets + 1] = w
				end
			end
		end
		content:SetHeight(-y + 10)

		local footer = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		footer:SetPoint("BOTTOMLEFT", 4, 8)
		if hiddenCount > 0 then
			footer:SetFormattedText("另有 %d 项待实机验证(TODO:VERIFY)后开放", hiddenCount)
		end

		page.reloadBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
		page.reloadBtn:SetSize(120, 22)
		page.reloadBtn:SetPoint("BOTTOMRIGHT", -30, 4)
		page.reloadBtn:SetText("重载界面生效")
		page.reloadBtn:SetScript("OnClick", function()
			if C_UI and C_UI.Reload then C_UI.Reload() end
		end)
		page.reloadBtn:Hide()

		function page:OnPageShow()
			for _, w in ipairs(self.widgets) do w:Update() end
			self.reloadBtn:SetShown(next(ns.Pending) ~= nil)
		end

		ns.Engine:AddListener(function()
			if page:IsShown() then page:OnPageShow() end
		end)

		return page
	end
end

for _, theme in ipairs(ns.Data.themes or {}) do
	ns.UI:RegisterPage("theme_" .. theme.key, theme.key .. " · " .. theme.title, buildThemePage(theme))
end
