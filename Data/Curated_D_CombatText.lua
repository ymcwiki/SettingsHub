-- P4 人工策展定版。官方面板只有总开关,_v2 细分家族全部隐藏,是「找回旧暴雪跳字」的原料
-- census 该主题 help 大面积错位,文案按 floatingCombatText 家族的公认语义撰写
local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.themes = ns.Data.themes or {}

ns.Data.themes[#ns.Data.themes + 1] = {
	key = "D", title = "战斗浮动文字",
	controls = {
		{ id = "combattext.floatingCombatTextCombatDamage_v2", domain = "cvar", key = "floatingCombatTextCombatDamage_v2", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "在敌人头上显示你造成的伤害数字(世界跳字总闸之一)。", en = { "damage numbers", "combat text" } } },
		{ id = "combattext.floatingCombatTextCombatHealing_v2", domain = "cvar", key = "floatingCombatTextCombatHealing_v2", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "显示你对目标的治疗数字。", en = { "healing numbers" } } },
		{ id = "combattext.floatingCombatTextCombatDamageAllAutos_v2", domain = "cvar", key = "floatingCombatTextCombatDamageAllAutos_v2", type = "bool", default = "1",
		  text = { zh = "显示全部普攻数字,而不是只显示事件性数字。", en = { "auto attack numbers" } } },
		{ id = "combattext.floatingCombatTextCombatLogPeriodicSpells_v2", domain = "cvar", key = "floatingCombatTextCombatLogPeriodicSpells_v2", type = "bool", default = "1",
		  text = { zh = "显示周期性效果(DoT/HoT)造成的数字。嫌刷屏就关它。", en = { "dot numbers", "periodic" } } },
		{ id = "combattext.floatingCombatTextPetMeleeDamage_v2", domain = "cvar", key = "floatingCombatTextPetMeleeDamage_v2", type = "bool", default = "1",
		  text = { zh = "显示宠物近战伤害数字。", en = { "pet melee" } } },
		{ id = "combattext.floatingCombatTextPetSpellDamage_v2", domain = "cvar", key = "floatingCombatTextPetSpellDamage_v2", type = "bool", default = "1",
		  text = { zh = "显示宠物法术伤害数字。", en = { "pet spell" } } },
		{ id = "combattext.floatingCombatTextCombatHealingAbsorbSelf_v2", domain = "cvar", key = "floatingCombatTextCombatHealingAbsorbSelf_v2", type = "bool", default = "1",
		  text = { zh = "显示你给自己上的护盾量。", en = { "absorb shield self" } } },
		{ id = "combattext.floatingCombatTextCombatHealingAbsorbTarget_v2", domain = "cvar", key = "floatingCombatTextCombatHealingAbsorbTarget_v2", type = "bool", default = "1",
		  text = { zh = "显示你给目标上的护盾量。", en = { "absorb shield target" } } },
		{ id = "combattext.floatingCombatTextCombatDamageDirectionalScale_v2", domain = "cvar", key = "floatingCombatTextCombatDamageDirectionalScale_v2", type = "number", default = "1", range = { 0, 3, 0.5 },
		  text = { zh = "伤害数字按打击方向飞散的幅度,0 关闭方向性漂移、数字原地上飘(经典旧观感)。", en = { "directional damage", "classic float" } } },
		{ id = "combattext.floatingCombatTextFloatMode_v2", domain = "cvar", key = "floatingCombatTextFloatMode_v2", type = "enum", default = "1",
		  values = { "1", "2", "3" }, valueLabels = { ["1"] = "上飘", ["2"] = "下沉", ["3"] = "弧线" },
		  text = { zh = "跳字漂移模式。", en = { "float mode", "arc" } } },
		{ id = "combattext.floatingCombatTextLowManaHealth_v2", domain = "cvar", key = "floatingCombatTextLowManaHealth_v2", type = "bool", default = "1",
		  text = { zh = "低血量/低法力时在角色身上跳提示。", en = { "low health warning" } } },
		{ id = "combattext.floatingCombatTextEnergyGains_v2", domain = "cvar", key = "floatingCombatTextEnergyGains_v2", type = "bool", default = "0",
		  text = { zh = "显示能量/怒气等资源获取数字。", en = { "energy gains" } } },
		{ id = "combattext.floatingCombatTextDodgeParryMiss_v2", domain = "cvar", key = "floatingCombatTextDodgeParryMiss_v2", type = "bool", default = "0",
		  text = { zh = "显示闪避/招架/未命中文字。", en = { "dodge parry miss" } } },
		{ id = "combattext.floatingCombatTextRepChanges_v2", domain = "cvar", key = "floatingCombatTextRepChanges_v2", type = "bool", default = "0",
		  text = { zh = "声望变化跳字。", en = { "reputation" } } },
		{ id = "combattext.WorldTextScale_v2", domain = "cvar", key = "WorldTextScale_v2", type = "number", default = "1", range = { 0.5, 3, 0.1 },
		  text = { zh = "世界跳字整体缩放。", en = { "combat text scale", "font size" } } },
		{ id = "combattext.WorldTextRampDuration_v2", domain = "cvar", key = "WorldTextRampDuration_v2", type = "number", default = "1", range = { 0.3, 3, 0.1 }, verify = true,
		  text = { zh = "跳字动画时长(秒)。TODO:VERIFY 单位与生效范围待实机确认。", en = { "ramp duration" } } },
		{ id = "combattext.WorldTextGravity_v2", domain = "cvar", key = "WorldTextGravity_v2", type = "number", default = "0.5", range = { 0, 3, 0.1 }, verify = true,
		  text = { zh = "跳字下坠重力系数。TODO:VERIFY 数值手感待实机确认。", en = { "gravity" } } },
	},
}
