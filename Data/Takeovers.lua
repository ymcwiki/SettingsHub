-- 外部插件接管特征库:只声明插件与受影响 CVar/主题的映射
local ADDON, ns = ...

ns.Data = ns.Data or {}

ns.Data.takeovers = {
	{
		key = "nameplate",
		addons = { "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates" },
		topics = { "nameplate" },
		text = {
			zh = "值没问题,姓名板可能由 %s 接管,请去它的姓名板设置里改。",
			en = "The value is fine, but %s may control nameplates. Change it in that addon's nameplate settings.",
		},
	},
	{
		key = "camera",
		addons = { "Leatrix_Plus", "ElvUI" },
		topics = { "camera" },
		text = {
			zh = "值没问题,镜头和视距可能由 %s 接管,请去它的镜头设置里改。",
			en = "The value is fine, but %s may control the camera and view distance. Change it in that addon's camera settings.",
		},
	},
	{
		key = "questmap",
		addons = { "Mapster", "SexyMap", "ElvUI" },
		topics = { "questmap" },
		text = {
			zh = "值没问题,地图或小地图可能由 %s 接管,请去它的地图设置里改。",
			en = "The value is fine, but %s may control the map or minimap. Change it in that addon's map settings.",
		},
	},
	{
		key = "actionbar",
		addons = { "Dominos", "Bartender4", "ElvUI" },
		topics = { "actionbar" },
		text = {
			zh = "值没问题,动作条或键位可能由 %s 接管,请去它的动作条设置里改。",
			en = "The value is fine, but %s may control action bars or bindings. Change it in that addon's action bar settings.",
		},
	},
	{
		key = "elvui",
		addons = { "ElvUI" },
		cvars = { "uiScale", "useUiScale" },
		topics = { "chat" },
		text = {
			zh = "值没问题,界面缩放或聊天可能由 %s 接管,请去它的界面或聊天设置里改。",
			en = "The value is fine, but %s may control UI scale or chat. Change it in that addon's UI or chat settings.",
		},
	},
	{
		key = "combattext",
		addons = { "MikScrollingBattleText", "xCT_Plus" },
		topics = { "combattext" },
		text = {
			zh = "值没问题,战斗跳字可能由 %s 接管,请去它的战斗文字设置里改。",
			en = "The value is fine, but %s may control combat text. Change it in that addon's combat text settings.",
		},
	},
}
