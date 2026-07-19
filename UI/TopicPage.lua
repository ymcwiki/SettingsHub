local ADDON, ns = ...
local L = ns.L
local Style = ns.Style

-- composite 只作数据分组；页面按叶子控件展平，逐项用 key 自动归主题。
local controlsByTopic = {}
for _, topic in ipairs(ns.Data.topicOrder) do controlsByTopic[topic.key] = {} end
controlsByTopic[ns.Data.TOPIC_OTHER.key] = {}

local function firstKey(controls)
	for _, control in ipairs(controls or {}) do
		if control.key then return control.key end
		local key = firstKey(control.children)
		if key then return key end
	end
end

local function collect(controls, fallbackTopic)
	for _, control in ipairs(controls or {}) do
		local topic = control.key and ns.Data.ClassifyTopic(control.key) or fallbackTopic
		if control.children then
			local childFallback = topic
			if not control.key then
				local key = firstKey(control.children)
				childFallback = key and ns.Data.ClassifyTopic(key) or fallbackTopic
			end
			collect(control.children, childFallback)
		else
			topic = topic or ns.Data.TOPIC_OTHER.key
			controlsByTopic[topic] = controlsByTopic[topic] or {}
			controlsByTopic[topic][#controlsByTopic[topic] + 1] = control
		end
	end
end

for _, theme in ipairs(ns.Data.themes or {}) do
	local key = firstKey(theme.controls)
	collect(theme.controls, key and ns.Data.ClassifyTopic(key) or ns.Data.TOPIC_OTHER.key)
end

local function buildMuteSection(page)
	local section = CreateFrame("Frame", nil, page)
	section:SetPoint("BOTTOMLEFT", 0, 0)
	section:SetPoint("BOTTOMRIGHT", 0, 0)
	section:SetHeight(Style.SoundMuteHeight)

	local separator = Style.Separator(section)
	separator:SetPoint("TOPLEFT", 0, 0)
	separator:SetPoint("TOPRIGHT", 0, 0)

	local header = Style.SectionHeader(section, L["Muted sounds (MuteSoundFile, replayed at login)"])
	header:SetPoint("TOPLEFT", 4, -8)

	-- 遗留:静音 fileID 输入按任务卡保留 InputBoxTemplate。
	local input = CreateFrame("EditBox", nil, section, "InputBoxTemplate")
	input:SetSize(Style.MuteInputWidth, Style.MuteInputHeight)
	input:SetPoint("TOPLEFT", 8, -30)
	input:SetAutoFocus(false)
	input:SetNumeric(true)
	local addBtn = ns.UI.Button(section, L["Add"], Style.MuteAddWidth, Style.MuteAddHeight)
	addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
	addBtn:SetScript("OnClick", function()
		local id = input:GetNumber()
		if id and id > 0 then
			ns.Engine:Set("mutesound", tostring(id), "1", "user")
			input:SetText("")
			page:OnPageShow()
		end
	end)
	local hint = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
	hint:SetText(L["Enter a soundKitFile fileID (look it up on wago.tools)"])

	local scroll = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -56)
	scroll:SetPoint("BOTTOMRIGHT", -28, 2)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(Style.CuratedContentWidth, 10)
	scroll:SetScrollChild(content)
	page.muteRows = {}

	function page:RefreshMuteList()
		for _, row in ipairs(self.muteRows) do row:Hide() end
		local y = 0
		for i, fileID in ipairs(ns.db.profile.mutesound) do
			local row = self.muteRows[i]
			if not row then
				row = CreateFrame("Frame", nil, content)
				row:SetSize(Style.MuteRowWidth, Style.MuteRowHeight)
				row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				row.text:SetPoint("LEFT", 12, 0)
				row.temp = ns.UI.Button(row, L["Unmute now"], Style.MuteTempWidth, Style.MuteTempHeight)
				row.temp:SetPoint("LEFT", 160, 0)
				row.del = ns.UI.Button(row, L["Remove"], Style.MuteRemoveWidth, Style.MuteRemoveHeight)
				row.del:SetPoint("LEFT", row.temp, "RIGHT", 6, 0)
				self.muteRows[i] = row
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, y)
			row.text:SetText(tostring(fileID))
			row.temp:SetScript("OnClick", function()
				ns.Adapters.mutesound:TempUnmute(fileID)
				ns.Print(string.format(L["%d unmuted for this session, mutes again next login"], fileID))
			end)
			row.del:SetScript("OnClick", function()
				ns.Engine:Set("mutesound", tostring(fileID), "0", "user")
				page:OnPageShow()
			end)
			row:Show()
			y = y - Style.MuteRowStep
		end
		content:SetHeight(math.max(10, -y))
	end

	return section
end

local function buildTopicPage(topicKey)
	return function(parent)
		local page = CreateFrame("Frame", nil, parent)
		local topicControls = controlsByTopic[topicKey] or {}

		page.widgets = {}
		local hiddenCount, missingCount = 0, 0
		local curated = CreateFrame("Frame", nil, page)
		curated:SetPoint("TOPLEFT", 0, 0)
		curated:SetPoint("TOPRIGHT", 0, 0)
		local curatedHeader = Style.SectionHeader(curated, L["Curated picks"])
		curatedHeader:SetPoint("TOPLEFT", 4, -4)

		page.reloadBtn = ns.UI.Button(curated, L["Reload UI to apply"],
			Style.ReloadButtonWidth, Style.ReloadButtonHeight, true)
		page.reloadBtn:SetPoint("TOPRIGHT", -28, 0)
		page.reloadBtn:SetScript("OnClick", function()
			if C_UI and C_UI.Reload then C_UI.Reload() end
		end)
		page.reloadBtn:Hide()

		local curatedScroll = CreateFrame("ScrollFrame", nil, curated, "UIPanelScrollFrameTemplate")
		curatedScroll:SetPoint("TOPLEFT", 0, -Style.SectionHeaderHeight)
		local curatedContent = CreateFrame("Frame", nil, curatedScroll)
		curatedContent:SetSize(Style.CuratedContentWidth, 10)
		curatedScroll:SetScrollChild(curatedContent)

		local y = 0
		for _, control in ipairs(topicControls) do
			if control.verify then
				hiddenCount = hiddenCount + 1
			elseif control.domain == "cvar" and control.key and not ns.Enum:Get(control.key) then
				-- 策展基准是 12.1.0，旧客户端不存在的项直接隐藏。
				missingCount = missingCount + 1
			else
				local widget = ns.Widgets.Create(curatedContent, control)
				if widget then
					widget:SetPoint("TOPLEFT", 0, y)
					widget:SetWidth(Style.CuratedContentWidth)
					y = y - widget:GetHeight() - 2
					page.widgets[#page.widgets + 1] = widget
				end
			end
		end
		local contentHeight = math.max(1, -y)
		curatedContent:SetHeight(contentHeight)

		local notes = {}
		if hiddenCount > 0 then
			notes[#notes + 1] = string.format(L["%d more entries hidden until verified in game (TODO:VERIFY)"], hiddenCount)
		end
		if missingCount > 0 then
			notes[#notes + 1] = string.format(L["%d entries not present on this client version, hidden"], missingCount)
		end
		local noteHeight = #notes > 0 and Style.NoteHeight or 0
		local footer = curated:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		footer:SetPoint("BOTTOMLEFT", 4, 2)
		footer:SetText(table.concat(notes, "  "))
		footer:SetShown(noteHeight > 0)

		local curatedVisible = #topicControls > 0
		local scrollHeight = math.min(contentHeight, Style.CuratedMaxHeight)
		local curatedHeight = Style.SectionHeaderHeight + scrollHeight + noteHeight + 4
		curated:SetHeight(curatedHeight)
		curatedScroll:SetPoint("BOTTOMRIGHT", -28, noteHeight + 2)
		curated:SetShown(curatedVisible)

		local sectionSeparator = Style.Separator(page)
		local listTitle = Style.SectionHeader(page, "")
		if curatedVisible then
			sectionSeparator:SetPoint("TOPLEFT", curated, "BOTTOMLEFT", 0, -4)
			sectionSeparator:SetPoint("TOPRIGHT", curated, "BOTTOMRIGHT", 0, -4)
			listTitle:SetPoint("TOPLEFT", sectionSeparator, "BOTTOMLEFT", 4, -7)
		else
			sectionSeparator:Hide()
			listTitle:SetPoint("TOPLEFT", 4, -4)
		end

		page.list = ns.UI.CreateCvarList(page, function()
			return "", topicKey
		end)
		page.list:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", -4, -6)
		page.list:SetPoint("RIGHT", page, "RIGHT", 0, 0)

		if topicKey == "sound" then
			page.muteSection = buildMuteSection(page)
			page.list:SetPoint("BOTTOM", page.muteSection, "TOP", 0, 6)
		else
			page.list:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
		end

		function page:OnPageShow()
			for _, widget in ipairs(self.widgets) do widget:Update() end
			self.reloadBtn:SetShown(curatedVisible and next(ns.Pending) ~= nil)
			self.list:Refresh()
			listTitle:SetFormattedText(L["All %d entries"], self.list.resultCount or 0)
			if self.RefreshMuteList then self:RefreshMuteList() end
		end

		ns.Engine:AddListener(function()
			if page:IsShown() then page:OnPageShow() end
		end)

		return page
	end
end

local function register(topic)
	local key = topic.key
	ns.UI:RegisterPage("topic_" .. key, ns.Data.TopicName(key), buildTopicPage(key), {
		visible = function()
			return (ns.Search:CategoryCounts()[key] or 0) > 0
		end,
	})
end

for _, topic in ipairs(ns.Data.topicOrder) do register(topic) end
register(ns.Data.TOPIC_OTHER)
