local ADDON, ns = ...
local L = ns.L
local Style = ns.Style

local function buildAll(parent)
	local page = CreateFrame("Frame", nil, parent)
	page.count = Style.SectionHeader(page, "")
	page.count:SetPoint("TOPLEFT", 0, -4)

	page.list = ns.UI.CreateCvarList(page, function()
		return ns.UI:GetSearchText(), nil
	end)
	page.list:SetPoint("TOPLEFT", 0, -26)
	page.list:SetPoint("BOTTOMRIGHT", 0, 0)
	function page.list:OnResultsChanged(n)
		page.count:SetFormattedText(L["%d / %d entries"], n, ns.Enum.count)
	end

	function page:OnSearch()
		self.list:Refresh()
	end

	function page:OnPageShow()
		self.list:Refresh()
	end

	return page
end

local function buildFavorites(parent)
	local page = CreateFrame("Frame", nil, parent)
	page.list = ns.UI.CreateCvarList(page, function()
		return "", "favorite"
	end)
	page.list:SetAllPoints(page)

	function page:OnPageShow()
		self.list:Refresh()
	end

	return page
end

ns.UI:RegisterPage("all", L["All Settings"], buildAll, { sepBefore = true })
ns.UI:RegisterPage("favorite", "★ " .. L["Favorites"], buildFavorites)
