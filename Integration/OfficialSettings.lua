local ADDON, ns = ...
local L = ns.L

local M = {}
ns.Integration = M

-- canvas 类别不进官方搜索,只当导航入口;可搜索项走 RegisterVerticalSubset
local function registerCanvas()
	local canvas = CreateFrame("Frame")
	local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -20)
	title:SetText("SettingsHub")
	local desc = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	desc:SetWidth(560)
	desc:SetJustifyH("LEFT")
	desc:SetText(L["In-game settings center: full CVar browser, themed panels, undo log and profiles. Official search only carries the curated subset; open the main window for everything."])
	local btn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	btn:SetSize(200, 28)
	btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
	btn:SetText(L["Open SettingsHub"])
	btn:SetScript("OnClick", function() ns.UI:Toggle() end)

	local category = Settings.RegisterCanvasLayoutCategory(canvas, "SettingsHub")
	Settings.RegisterAddOnCategory(category)
	M.canvasCategory = category
end

-- 精选策展子集注册进官方 vertical layout,AddSearchTags 中英同义词(P4 数据就位后生效)
local variableByKey = {}
-- 官方 setting 的值后备表。注意:RegisterAddOnSetting 的 setting 从这张表读值,
-- 我们写管线改完 CVar 必须先同步这张表再 NotifyUpdate,否则官方 setting 会拿
-- 注册时的旧值经 SetValueChangedCallback 反向写回,把用户的修改当场抵消
-- (12.0.7 实机「officialSearch 项点不动」根因,回归测试见 tests/run.lua)
local proxy = {}

local function registerVerticalSubset()
	if not (Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
	local category = Settings.RegisterVerticalLayoutCategory(L["SettingsHub Picks"])
	local n = 0
	for _, th in ipairs(ns.Data.themes or {}) do
		for _, c in ipairs(th.controls) do
			if c.officialSearch and c.domain == "cvar" and c.type == "bool"
				and ns.ControlText(c) ~= "" then
				local info = ns.Enum:Get(c.key)
				if info and not info.readonly then
					local variable = "SETTINGSHUB_" .. c.id
					variableByKey[c.key] = variable
					proxy[variable] = info.value == "1"
					local setting = Settings.RegisterAddOnSetting(category, variable, variable, proxy,
						Settings.VarType.Boolean, c.key, info.default == "1")
					setting:SetValueChangedCallback(function(s)
						if M._notifying then return end
						M._fromOfficial = true
						ns.Engine:Set("cvar", c.key, s:GetValue() and "1" or "0", "user")
						M._fromOfficial = false
					end)
					-- 官方面板行名用当前语言描述,搜索标签中英关键词都注册
					local initializer = Settings.CreateCheckbox(category, setting, ns.ControlLabel(c))
					if initializer and initializer.AddSearchTags then
						initializer:AddSearchTags(c.key, unpack(c.text.keywords or {}))
					end
					n = n + 1
				end
			end
		end
	end
	Settings.RegisterAddOnCategory(category)
	M.verticalCategory = category
	M.registeredCount = n
end

function M:Register()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
	registerCanvas()
	registerVerticalSubset()
end

-- 本插件改值后让官方面板同步显示(打开着官方设置时);来自官方回调的写入不用回notify
function M:NotifyOfficial(key)
	if self._fromOfficial then return end
	local variable = variableByKey[key]
	if variable and Settings and Settings.NotifyUpdate then
		proxy[variable] = ns.Adapters.cvar:Read(key) == "1"
		self._notifying = true
		Settings.NotifyUpdate(variable)
		self._notifying = false
	end
end
