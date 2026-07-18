local ADDON, ns = ...
local L = ns.L

local function T(tbl)
	return ns.IsCJK() and tbl.zh or tbl.en
end

StaticPopupDialogs["SETTINGSHUB_PACK_CONFIRM"] = {
	text = "%s",
	button1 = YES, button2 = NO,
	OnAccept = function(_, pack)
		local applied, queued, failed = ns.Packs:Apply(pack)
		ns.Print(string.format(L["Pack [%s] applied: %d ok, %d queued (combat), %d failed. Undo it as a whole from the Log page."],
			T(pack.title), applied, queued, failed))
		ns.UI:Refresh()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function previewAndConfirm(pack)
	local changes, unknown = ns.Packs:Preview(pack)
	if #changes == 0 then
		ns.Print(string.format("[%s] %s", T(pack.title), L["already matches your current values, nothing to change"]))
		return
	end
	for _, c in ipairs(changes) do
		ns.Print(string.format(L["  %s: %s changed to %s"], c.key, c.old, c.new))
	end
	local summary = string.format(
		L["Apply pack [%s]: %d values change (details in chat)%s. One bulk snapshot is logged first, so the whole pack can be undone."],
		T(pack.title), #changes,
		unknown > 0 and string.format(L[", %d unknown on this client will be skipped"], unknown) or "")
	StaticPopup_Show("SETTINGSHUB_PACK_CONFIRM", summary, nil, pack)
end

local function build(parent)
	local page = CreateFrame("Frame", nil, parent)

	local intro = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	intro:SetPoint("TOPLEFT", 4, -4)
	intro:SetWidth(780)
	intro:SetJustifyH("LEFT")
	intro:SetWordWrap(true)
	intro:SetText(L["Curated one-click bundles. Apply shows a preview first; every applied pack is one bulk entry in the undo log."])

	-- 试穿状态条:有活动试穿时显示剩余时间与两个处置按钮
	page.trialText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.trialText:SetPoint("TOPLEFT", 4, -22)
	page.trialRevert = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	page.trialRevert:SetSize(90, 20)
	page.trialRevert:SetPoint("TOPRIGHT", -220, -18)
	page.trialRevert:SetText(L["Revert now"])
	page.trialRevert:SetScript("OnClick", function()
		ns.Trial:Revert("manual")
		page:OnPageShow()
	end)
	page.trialPromote = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	page.trialPromote:SetSize(90, 20)
	page.trialPromote:SetPoint("LEFT", page.trialRevert, "RIGHT", 6, 0)
	page.trialPromote:SetText(L["Keep it"])
	page.trialPromote:SetScript("OnClick", function()
		ns.Trial:Promote()
		page:OnPageShow()
	end)

	page.rows = {}
	local y = -48
	for _, pack in ipairs(ns.Data.packs or {}) do
		local row = CreateFrame("Frame", nil, page)
		row:SetPoint("TOPLEFT", 0, y)
		row:SetSize(820, 10)

		-- 图标按 pack-<key>.png 命名约定加载,无头测试保证文件存在
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(48, 48)
		icon:SetPoint("TOPLEFT", 4, -4)
		icon:SetTexture("Interface\\AddOns\\SettingsHub\\Media\\pack-" .. pack.key .. ".png")

		local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 62, 0)
		title:SetText(T(pack.title))

		local count = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		count:SetPoint("LEFT", title, "RIGHT", 10, 0)

		local applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		applyBtn:SetSize(120, 22)
		applyBtn:SetPoint("TOPRIGHT", -8, 2)
		applyBtn:SetText(L["Preview & apply"])
		applyBtn:SetScript("OnClick", function() previewAndConfirm(pack) end)

		-- 试穿:临时应用,10 分钟后自动还原(登出/手动还原/转常驻见顶部状态条)
		local trialBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		trialBtn:SetSize(120, 22)
		trialBtn:SetPoint("TOPRIGHT", -8, -22)
		trialBtn:SetText(L["Try for 10 min"])
		trialBtn:SetScript("OnClick", function()
			local n, err = ns.Trial:Start(pack.values, 10, T(pack.title))
			if not n then
				ns.Print(L["A trial is already running; revert or keep it first"])
			else
				ns.Print(string.format(L["Trying pack [%s]: %d values applied, auto-reverts in 10 minutes"], T(pack.title), n))
			end
			page:OnPageShow()
		end)

		local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		desc:SetPoint("TOPLEFT", 62, -22)
		desc:SetWidth(600)
		desc:SetJustifyH("LEFT")
		desc:SetWordWrap(true)
		desc:SetText(T(pack.text))

		local keys = {}
		for _, item in ipairs(pack.values) do keys[#keys + 1] = item.key .. "=" .. item.value end
		local detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		detail:SetPoint("TOPLEFT", 62, -24 - desc:GetStringHeight())
		detail:SetWidth(720)
		detail:SetJustifyH("LEFT")
		detail:SetWordWrap(true)
		detail:SetText(table.concat(keys, "   "))

		local h = 30 + desc:GetStringHeight() + detail:GetStringHeight()
		if h < 56 then h = 56 end
		row:SetHeight(h)
		row.count, row.pack = count, pack
		page.rows[#page.rows + 1] = row
		y = y - h - 16
	end

	function page:OnPageShow()
		for _, row in ipairs(self.rows) do
			local changes = ns.Packs:Preview(row.pack)
			row.count:SetFormattedText(L["%d settings, %d differ from current"], #row.pack.values, #changes)
		end
		local tr = ns.Trial:Active()
		if tr then
			local remain = math.max(0, math.floor((tr.expires - time()) / 60))
			self.trialText:SetFormattedText("|cffffcc00" .. L["Trial running: [%s], about %d min left"] .. "|r",
				tostring(tr.label), remain)
		else
			self.trialText:SetText("")
		end
		self.trialText:SetShown(tr ~= nil)
		self.trialRevert:SetShown(tr ~= nil)
		self.trialPromote:SetShown(tr ~= nil)
	end

	ns.Engine:AddListener(function()
		if page:IsShown() then page:OnPageShow() end
	end)

	return page
end

ns.UI:RegisterPage("packs", L["Recommended Packs"], build)
