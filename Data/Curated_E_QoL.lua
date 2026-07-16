-- P4 人工策展定版。lastTransmog*/transmogrify*Filters 等纯 UI 状态记忆位已剔除
local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.themes = ns.Data.themes or {}

ns.Data.themes[#ns.Data.themes + 1] = {
	key = "E", title = "界面与 QoL 杂项",
	controls = {
		{ id = "qol.rawMouseEnable", domain = "cvar", key = "rawMouseEnable", type = "bool", default = "0", officialSearch = true,
		  text = { zh = "原始鼠标输入:绕过系统指针加速,转镜头手感与系统灵敏度脱钩。镜头漂、加速度不一致就开它(823 字节的 RawMouseEnable 插件整个产品就这一个开关)。", en = { "raw mouse", "mouse acceleration", "input" } } },
		{ id = "qol.SpellQueueWindow", domain = "cvar", key = "SpellQueueWindow", type = "number", default = "400", range = { 0, 400, 25 },
		  text = { zh = "技能预按队列窗口(毫秒):提前多久按下一个技能会被排进队列。高延迟调大,追求手感的玩家常压到 100 左右。", en = { "spell queue window", "latency", "input lag" } } },
		{ id = "qol.alwaysCompareItems", domain = "cvar", key = "alwaysCompareItems", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "鼠标指向装备时总是显示对比 tooltip,不用按 Shift。", en = { "compare items", "tooltip" } } },
		{ id = "qol.breakUpLargeNumbers", domain = "cvar", key = "breakUpLargeNumbers", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "大数字加千位分隔符(1,234,567)。", en = { "large numbers", "comma" } } },
		{ id = "qol.autoLootRate", domain = "cvar", key = "autoLootRate", type = "number", default = "150", range = { 0, 500, 25 },
		  text = { zh = "自动拾取的逐件间隔(毫秒)。调小拾取更快,太小可能被服务器限速。", en = { "auto loot rate", "loot speed" } } },
		{ id = "qol.violenceLevel", domain = "cvar", key = "violenceLevel", type = "enum", default = "2",
		  values = { "0", "1", "2", "3", "4", "5" },
		  text = { zh = "血腥程度等级(0 最低,5 最高),影响击杀血液与尸体效果。", en = { "violence level", "blood" } } },
		{ id = "qol.uiScaleMultiplier", domain = "cvar", key = "uiScaleMultiplier", type = "number", default = "-1", range = { -1, 2, 0.05 }, secure = true,
		  text = { zh = "整体 UI 缩放乘数:-1 按显示器 DPI 自动,0.5 到 2.0 手动指定。4K 屏 UI 太小的救星。", en = { "ui scale", "dpi", "hidpi" } } },
		{ id = "qol.discordClientEnabled", domain = "cvar", key = "discordClientEnabled", type = "bool", default = "1", version = { added = "12.1.0" },
		  text = { zh = "Discord 客户端集成开关(游戏内状态同步)。不用 Discord 可以关掉。", en = { "discord" } } },
		{ id = "qol.threatWarning", domain = "cvar", key = "threatWarning", type = "enum", default = "3",
		  values = { "0", "1", "2", "3" }, valueLabels = { ["0"] = "关闭", ["1"] = "仅地城", ["2"] = "队伍/团队", ["3"] = "总是" },
		  text = { zh = "仇恨警告 UI 什么时候出现。", en = { "threat warning", "aggro" } } },
		{ id = "qol.threatShowNumeric", domain = "cvar", key = "threatShowNumeric", type = "bool", default = "0", officialSearch = true,
		  text = { zh = "目标/焦点框体显示仇恨百分比数字。坦克与输出卡仇恨的原生方案,不用装仇恨插件。", en = { "threat numeric", "threat percent" } } },
		{ id = "qol.threatPlaySounds", domain = "cvar", key = "threatPlaySounds", type = "bool", default = "1",
		  text = { zh = "仇恨状态变化时播放提示音。", en = { "threat sounds" } } },
		{ id = "qol.threatWorldText", domain = "cvar", key = "threatWorldText", type = "bool", default = "1",
		  text = { zh = "战斗中显示仇恨相关的世界跳字。", en = { "threat text" } } },
		{ id = "qol.missingTransmogSourceInItemTooltips", domain = "cvar", key = "missingTransmogSourceInItemTooltips", type = "bool", default = "0", officialSearch = true,
		  text = { zh = "tooltip 标注「外观已收集但此来源未收集」。幻化收集党必开。", en = { "transmog source", "appearance collected" } } },
		{ id = "qol.showAllItemsInTransmog", domain = "cvar", key = "showAllItemsInTransmog", type = "bool", default = "0", officialSearch = true,
		  text = { zh = "幻化台显示全部物品,无视护甲类型限制(预览用)。", en = { "transmog all items" } } },
		{ id = "qol.transmogCurrentSpecOnly", domain = "cvar", key = "transmogCurrentSpecOnly", type = "bool", default = "0",
		  text = { zh = "幻化只应用到当前专精,而不是全部专精。", en = { "transmog spec" } } },
	},
}
