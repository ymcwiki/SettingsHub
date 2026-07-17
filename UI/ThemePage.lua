local ADDON, ns = ...
local L = ns.L

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
		-- G 主题页尾部追加静音音效列表管理(MuteSoundFile 域)
		if theme.key == "G" then
			local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			header:SetPoint("TOPLEFT", 4, y - 10)
			header:SetText(L["Muted sounds (MuteSoundFile, replayed at login)"])
			local input = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
			input:SetSize(120, 20)
			input:SetPoint("TOPLEFT", 8, y - 34)
			input:SetAutoFocus(false)
			input:SetNumeric(true)
			local addBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
			addBtn:SetSize(60, 22)
			addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
			addBtn:SetText(L["Add"])
			addBtn:SetScript("OnClick", function()
				local id = input:GetNumber()
				if id and id > 0 then
					ns.Engine:Set("mutesound", tostring(id), "1", "user")
					input:SetText("")
					page:OnPageShow()
				end
			end)
			local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			hint:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
			hint:SetText(L["Enter a soundKitFile fileID (look it up on wago.tools)"])
			y = y - 62
			page.muteRows = {}
			page.muteAnchorY = y
			function page:RefreshMuteList()
				for _, r in ipairs(self.muteRows) do r:Hide() end
				local ry = self.muteAnchorY
				for i, fileID in ipairs(ns.db.profile.mutesound) do
					local r = self.muteRows[i]
					if not r then
						r = CreateFrame("Frame", nil, content)
						r:SetSize(500, 22)
						r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
						r.text:SetPoint("LEFT", 12, 0)
						r.temp = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
						r.temp:SetSize(76, 18)
						r.temp:SetPoint("LEFT", 160, 0)
						r.temp:SetText(L["Unmute now"])
						r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
						r.del:SetSize(50, 18)
						r.del:SetPoint("LEFT", r.temp, "RIGHT", 6, 0)
						r.del:SetText(L["Remove"])
						self.muteRows[i] = r
					end
					r:SetPoint("TOPLEFT", 0, ry)
					r.text:SetText(tostring(fileID))
					r.temp:SetScript("OnClick", function()
						ns.Adapters.mutesound:TempUnmute(fileID)
						ns.Print(string.format(L["%d unmuted for this session, mutes again next login"], fileID))
					end)
					r.del:SetScript("OnClick", function()
						ns.Engine:Set("mutesound", tostring(fileID), "0", "user")
						page:OnPageShow()
					end)
					r:Show()
					ry = ry - 24
				end
				content:SetHeight(-ry + 10)
			end
		end
		content:SetHeight(-y + 10)

		local footer = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		footer:SetPoint("BOTTOMLEFT", 4, 8)
		if hiddenCount > 0 then
			footer:SetFormattedText(L["%d more entries hidden until verified in game (TODO:VERIFY)"], hiddenCount)
		end

		page.reloadBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
		page.reloadBtn:SetSize(120, 22)
		page.reloadBtn:SetPoint("BOTTOMRIGHT", -30, 4)
		page.reloadBtn:SetText(L["Reload UI to apply"])
		page.reloadBtn:SetScript("OnClick", function()
			if C_UI and C_UI.Reload then C_UI.Reload() end
		end)
		page.reloadBtn:Hide()

		function page:OnPageShow()
			for _, w in ipairs(self.widgets) do w:Update() end
			self.reloadBtn:SetShown(next(ns.Pending) ~= nil)
			if self.RefreshMuteList then self:RefreshMuteList() end
		end

		ns.Engine:AddListener(function()
			if page:IsShown() then page:OnPageShow() end
		end)

		return page
	end
end

for _, theme in ipairs(ns.Data.themes or {}) do
	ns.UI:RegisterPage("theme_" .. theme.key, theme.key .. " · " .. L[theme.title], buildThemePage(theme))
end
