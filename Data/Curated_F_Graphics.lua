-- P4 人工策展定版。RAID* 是进副本自动切换的档位镜像,与野外基础项成对展示;
-- raidFrames*/raidOption* 属 CUF 域(SPEC 排除),不收录
local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.themes = ns.Data.themes or {}

ns.Data.themes[#ns.Data.themes + 1] = {
	key = "F", title = "图形性能与画质",
	controls = {
		{ id = "graphics.ffxGlow", domain = "cvar", key = "ffxGlow", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "全屏泛光(bloom)效果。嫌画面发灰发亮的第一个要关的开关。", en = { "glow", "bloom", "full screen effect" } } },
		{ id = "graphics.ffxDeath", domain = "cvar", key = "ffxDeath", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "死亡时的全屏黑白效果。关掉后死了画面照样有颜色。", en = { "death effect", "desaturate" } } },
		{ id = "graphics.ffxNether", domain = "cvar", key = "ffxNether", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "虚空/灵魂状态的全屏扭曲效果。", en = { "nether effect" } } },
		{ id = "graphics.weatherDensity", domain = "cvar", key = "weatherDensity", type = "enum", default = "2",
		  values = { "0", "1", "2", "3" }, valueLabels = { ["0"] = "关闭", ["1"] = "低", ["2"] = "中", ["3"] = "高" },
		  text = { zh = "天气效果密度(雨雪粒子)。", en = { "weather density", "rain snow" } } },
		{ id = "graphics.RAIDweatherDensity", domain = "cvar", key = "RAIDweatherDensity", type = "enum", default = "2",
		  values = { "0", "1", "2", "3" }, valueLabels = { ["0"] = "关闭", ["1"] = "低", ["2"] = "中", ["3"] = "高" },
		  text = { zh = "副本档位:进入团本后自动生效的天气密度(与上一项成对,Hyperframe 整个产品建立在这套 RAID* 镜像上)。", en = { "raid weather" } } },
		{ id = "graphics.farclip", domain = "cvar", key = "farclip", type = "number", default = "1000", range = { 177, 10000, 100 },
		  text = { zh = "远景裁剪距离,越大看得越远、越吃性能。", en = { "view distance", "farclip" } } },
		{ id = "graphics.RAIDfarclip", domain = "cvar", key = "RAIDfarclip", type = "number", default = "1000", range = { 177, 10000, 100 },
		  text = { zh = "副本档位:团本内的远景裁剪距离。打本降它保帧数,野外照常看风景。", en = { "raid view distance" } } },
		{ id = "graphics.DynamicRenderScale", domain = "cvar", key = "DynamicRenderScale", type = "bool", default = "0",
		  text = { zh = "动态渲染分辨率:GPU 吃紧时自动降低渲染比例保住目标帧数(官方标注 BETA)。", en = { "dynamic render scale", "fps" } } },
		{ id = "graphics.DynamicRenderScaleMin", domain = "cvar", key = "DynamicRenderScaleMin", type = "number", default = "0.33", range = { 0.1, 1, 0.01 }, verify = true,
		  text = { zh = "动态渲染分辨率允许降到的最低比例。TODO:VERIFY 取值步进待实机确认。", en = { "render scale min" } } },
		{ id = "graphics.RAIDshadowMode", domain = "cvar", key = "RAIDshadowMode", type = "enum", default = "0",
		  values = { "0", "1", "2", "3" }, valueLabels = { ["0"] = "最低", ["1"] = "低", ["2"] = "中", ["3"] = "高" },
		  text = { zh = "副本档位:团本内阴影质量。默认 0,打本最常见的隐藏减负项。", en = { "raid shadows" } } },
		{ id = "graphics.RAIDparticleDensity", domain = "cvar", key = "RAIDparticleDensity", type = "number", default = "100", range = { 10, 100, 10 },
		  text = { zh = "副本档位:团本内粒子密度(百分比)。技能特效糊满屏时降它。", en = { "raid particle density", "spell effects" } } },
		{ id = "graphics.RAIDspellClutter", domain = "cvar", key = "RAIDspellClutter", type = "enum", default = "2", verify = true,
		  values = { "0", "1", "2" },
		  text = { zh = "副本档位:法术视觉密度分级。TODO:VERIFY 取值语义待实机确认。", en = { "spell clutter", "spell density" } } },
		{ id = "graphics.screenshotFormat", domain = "cvar", key = "screenshotFormat", type = "enum", default = "jpeg",
		  values = { "jpeg", "tga", "png" },
		  text = { zh = "截图格式。要无损用 png/tga。", en = { "screenshot format" } } },
		{ id = "graphics.screenshotQuality", domain = "cvar", key = "screenshotQuality", type = "number", default = "3", range = { 1, 10, 1 },
		  text = { zh = "JPEG 截图质量(1 到 10)。", en = { "screenshot quality" } } },
		{ id = "graphics.screenshotSizeOverride", domain = "cvar", key = "screenshotSizeOverride", type = "string", default = "0x0",
		  text = { zh = "超采样截图:按指定分辨率(如 7680x4320)渲染截图,0x0 为跟随窗口。壁纸党神器,极高分辨率可能失败。", en = { "supersample screenshot", "resolution" } } },
	},
}
