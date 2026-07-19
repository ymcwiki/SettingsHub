-- v0.4 发现层数据:意图引导(items 引用策展控件 id,测试保证可解析)+ 主动建议(声明式条件)
-- 调研第二章:「策展式设置推荐引导层」是空白市场,这份数据就是那一层的内容
local ADDON, ns = ...

ns.Data = ns.Data or {}

ns.Data.guides = {
	{ key = "wanted",
	  title = { zh = "最想要的隐藏设置", en = "Most-wanted hidden settings" },
	  blurb = { zh = "社区里问得最多、官方选项里却偏偏没有的那几项,在这儿直接调。每项都有说明,不用记控制台命令,也不用装一堆小插件。", en = "The handful people ask about most that the official Options panel never exposes. Tune them right here, each one explained, no console commands to memorize and no pile of micro-addons." },
	  items = { "camera.cameraDistanceMaxZoomFactor", "qol.SpellQueueWindow", "nameplate.nameplateMaxDistance", "graphics.ffxGlow", "graphics.ffxDeath", "sound.Sound_EnableArmorFoleySoundForSelf", "nameplate.nameplateOverlapH", "qol.rawMouseEnable" } },
	{ key = "motionsick",
	  title = { zh = "我晕 3D", en = "Motion sickness" },
	  blurb = { zh = "镜头随速度和动作晃动是主要诱因,这几项全关,世界立刻稳下来。", en = "Camera sway tied to speed and motion is the main trigger; turn these off and the world settles down." },
	  items = { "camera.AdvFlyingDynamicFOVEnabled", "camera.DriveDynamicFOVEnabled", "graphics.ffxNether" },
	  pack = "comfort" },
	{ key = "fps",
	  title = { zh = "我帧数低", en = "Low framerate" },
	  blurb = { zh = "先动 RAID* 副本档位:只影响团本内画质,野外照常。这是 Hyperframe 卖了 22 万下载的那套隐藏项。", en = "Start with the RAID* tier: it only affects visuals inside raids, the open world stays untouched. These are the hidden values Hyperframe built 225k downloads on." },
	  items = { "graphics.RAIDshadowMode", "graphics.RAIDparticleDensity", "graphics.RAIDfarclip", "graphics.DynamicRenderScale" },
	  pack = "raidperf" },
	{ key = "healer",
	  title = { zh = "我玩治疗", en = "Playing healer" },
	  blurb = { zh = "友方软目标全家桶:指哪奶哪,不用精确点框体。", en = "The friendly soft-target family: heal what you point at, no precise frame clicking needed." },
	  items = { "target.SoftTargetFriend", "target.SoftTargetFriendRange", "target.SoftTargetTooltipFriend", "nameplate.nameplateShowFriendlyClassColor" } },
	{ key = "pvp",
	  title = { zh = "我打 PvP", en = "PvP player" },
	  blurb = { zh = "敌方召唤物的姓名板默认全关,开了才看得见腾和宠。", en = "Nameplates for enemy summons are all off by default; turn them on and totems and pets stop hiding." },
	  items = { "nameplate.nameplateShowEnemyTotems", "nameplate.nameplateShowEnemyPets", "nameplate.nameplateShowEnemyGuardians" },
	  pack = "pvpinfo" },
	{ key = "capture",
	  title = { zh = "我要录屏截图", en = "Recording & screenshots" },
	  blurb = { zh = "超采样截图配无损格式出壁纸;录屏要录到鼠标指针的话,把硬件光标关掉。", en = "Supersampled screenshots plus a lossless format make wallpapers; if your recording needs the pointer visible, turn hardware cursor off." },
	  items = { "graphics.screenshotSizeOverride", "graphics.screenshotFormat", "graphics.screenshotQuality", "input.HardwareCursor" } },
	{ key = "gamepad",
	  title = { zh = "我用手柄", en = "On a gamepad" },
	  blurb = { zh = "原生手柄支持藏得很深,总开关在这,ConsolePort 也要求先开它。", en = "Native gamepad support is buried; the master switch lives here, and ConsolePort wants it on first." },
	  items = { "input.GamePadEnable", "input.GamePadCursorAutoEnable", "input.GamePadCameraPitchSpeed", "input.GamePadVibrationStrength" } },
	{ key = "starter",
	  title = { zh = "我刚装好游戏", en = "Fresh install" },
	  blurb = { zh = "老玩家每台新机器都要改的那几项,一个包全带走。", en = "The handful veterans change on every fresh machine, bundled." },
	  items = { "camera.cameraDistanceMaxZoomFactor", "qol.rawMouseEnable", "qol.threatShowNumeric" },
	  pack = "starter" },
	{ key = "author",
	  title = { zh = "我写插件", en = "Addon author" },
	  blurb = { zh = "报错弹窗、taint 日志、合规六件套,H 主题就是给你准备的合规测试面板。", en = "Error popups, taint logging and the compliance sextet: theme H is your compliance test panel." },
	  items = { "dev.scriptErrors", "dev.taintLog", "dev.addonCombatRestrictionsForced" } },
}

-- 主动建议:条件为真才显示;suggest 是一键处理写入的值;可「不再提示」
-- op: eq(字符串相等) / lt / gt(数值比较)
ns.Data.tips = {
	{ key = "armorfoley", cvar = "Sound_EnableArmorFoleySoundForSelf", op = "eq", value = "1", suggest = "0",
	  text = { zh = "自己的盔甲摩擦音开着。12.0 加入后社区呼声最高的「怎么关」项,关了世界清净。",
	    en = "Your own armor foley is on. The loudest how-do-I-turn-this-off request since 12.0; off means quiet." },
	  action = { zh = "关闭它", en = "Turn it off" } },
	{ key = "maxzoom", cvar = "cameraDistanceMaxZoomFactor", op = "lt", value = "2.6", suggest = "2.6",
	  text = { zh = "最大视距倍率没拉满。2.6 是引擎上限,官方滑条不给,团本看场地全靠它。",
	    en = "Max camera distance is not at the cap. 2.6 is the engine limit the official slider never offers; raid sightlines live here." },
	  action = { zh = "拉到 2.6", en = "Set to 2.6" } },
	{ key = "taintlog", cvar = "taintLog", op = "gt", value = "0", suggest = "0",
	  text = { zh = "taint 日志开着(级别大于 0),排障期之外常开有性能开销,日志文件也会越滚越大。",
	    en = "Taint logging is on (level above 0). Outside a debugging session it costs performance and the log file keeps growing." },
	  action = { zh = "关闭", en = "Turn off" } },
	{ key = "scriptprofile", cvar = "scriptProfile", op = "eq", value = "1", suggest = "0",
	  text = { zh = "脚本性能分析开着,常开有稳定的 CPU 开销。不在分析插件性能就关掉(需 /reload 生效)。",
	    en = "Script profiling is on, which costs steady CPU. Turn it off unless you are actively profiling addons (takes effect after /reload)." },
	  action = { zh = "关闭", en = "Turn off" } },
}
