-- P4 人工策展定版。addon*RestrictionsForced 六件套即 12.0.5+ 官方合规自测开关,
-- 本主题就是插件作者的「合规测试面板」(差异化卖点,Leatrix/Plumber 各自内置过散装版)
local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.themes = ns.Data.themes or {}

ns.Data.themes[#ns.Data.themes + 1] = {
	key = "H", title = "开发者",
	controls = {
		{ id = "dev.scriptErrors", domain = "cvar", key = "scriptErrors", type = "bool", default = "0",
		  text = { zh = "显示 Lua 报错弹窗。排查插件问题第一开关。", en = { "script errors", "lua errors" } } },
		{ id = "dev.taintLog", domain = "cvar", key = "taintLog", type = "enum", default = "0",
		  values = { "0", "1", "2" }, valueLabels = { ["0"] = "关闭", ["1"] = "基本", ["2"] = "详细" },
		  text = { zh = "taint 日志级别,写入 Logs/taint.log。查「插件污染保护功能」问题用 2。", en = { "taint log" } } },
		{ id = "dev.taintLogObjectSecrets", domain = "cvar", key = "taintLogObjectSecrets", type = "bool", default = "0", version = { added = "12.1.0" },
		  text = { zh = "taint 日志追加记录脚本对象获得 secret 属性的事件,Midnight secret values 排障利器。", en = { "secret values log" } } },
		{ id = "dev.scriptProfile", domain = "cvar", key = "scriptProfile", type = "bool", default = "0", requiresReload = true,
		  text = { zh = "脚本性能分析(AddOn CPU 采集),改后需 /reload 生效,常开有性能开销。", en = { "script profile", "cpu profiling" } } },
		{ id = "dev.addonLoadDebugging", domain = "cvar", key = "addonLoadDebugging", type = "bool", default = "0",
		  text = { zh = "插件加载日志写入 AddOnLoad.log。", en = { "addon load log" } } },
		{ id = "dev.addonCombatRestrictionsForced", domain = "cvar", key = "addonCombatRestrictionsForced", type = "bool", default = "0",
		  text = { zh = "强制进入战斗限制状态:不打木桩即可测试插件的战斗锁定行为(API 受限或返回 secret)。", en = { "combat restrictions forced" } } },
		{ id = "dev.addonEncounterRestrictionsForced", domain = "cvar", key = "addonEncounterRestrictionsForced", type = "bool", default = "0",
		  text = { zh = "强制进入首领战限制状态。", en = { "encounter restrictions" } } },
		{ id = "dev.addonChallengeModeRestrictionsForced", domain = "cvar", key = "addonChallengeModeRestrictionsForced", type = "bool", default = "0",
		  text = { zh = "强制进入大秘境限制状态。", en = { "challenge mode restrictions", "mythic plus" } } },
		{ id = "dev.addonPvPMatchRestrictionsForced", domain = "cvar", key = "addonPvPMatchRestrictionsForced", type = "bool", default = "0",
		  text = { zh = "强制进入 PvP 比赛限制状态。", en = { "pvp restrictions" } } },
		{ id = "dev.addonMapRestrictionsForced", domain = "cvar", key = "addonMapRestrictionsForced", type = "bool", default = "0",
		  text = { zh = "强制按地图类型限制 API。", en = { "map restrictions" } } },
		{ id = "dev.addonChatRestrictionsForced", domain = "cvar", key = "addonChatRestrictionsForced", type = "bool", default = "0",
		  text = { zh = "强制进入聊天锁定状态(六件套中唯一文档确认跨重启持久性的存疑项,见 VERIFIED.md)。", en = { "chat restrictions" } } },
	},
}
