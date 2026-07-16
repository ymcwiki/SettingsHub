local ADDON, ns = ...

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
	desc:SetText("游戏内设置中心:全量 CVar 浏览器、主题面板、撤销日志与 profile。官方搜索只收录精选注册项,完整功能请打开主窗口。")
	local btn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	btn:SetSize(200, 28)
	btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
	btn:SetText("打开 SettingsHub")
	btn:SetScript("OnClick", function() ns.UI:Toggle() end)

	local category = Settings.RegisterCanvasLayoutCategory(canvas, "SettingsHub")
	Settings.RegisterAddOnCategory(category)
	M.canvasCategory = category
end

-- 精选策展子集注册进官方 vertical layout,AddSearchTags 中英同义词(P4 数据就位后生效)
local variableByKey = {}

local function registerVerticalSubset()
	if not (Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
	local category = Settings.RegisterVerticalLayoutCategory("SettingsHub 精选")
	local proxy = {}
	local n = 0
	for _, th in ipairs(ns.Data.themes or {}) do
		for _, c in ipairs(th.controls) do
			if c.officialSearch and c.domain == "cvar" and c.type == "bool"
				and c.text and c.text.zh ~= "" then
				local info = ns.Enum:Get(c.key)
				if info and not info.readonly then
					local variable = "SETTINGSHUB_" .. c.id
					variableByKey[c.key] = variable
					proxy[variable] = info.value == "1"
					local setting = Settings.RegisterAddOnSetting(category, variable, variable, proxy,
						Settings.VarType.Boolean, c.key, info.default == "1")
					setting:SetValueChangedCallback(function(s)
						M._fromOfficial = true
						ns.Engine:Set("cvar", c.key, s:GetValue() and "1" or "0", "user")
						M._fromOfficial = false
					end)
					local initializer = Settings.CreateCheckbox(category, setting, c.text.zh)
					if initializer and initializer.AddSearchTags then
						initializer:AddSearchTags(c.key, unpack(c.text.en or {}))
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
		Settings.NotifyUpdate(variable)
	end
end
