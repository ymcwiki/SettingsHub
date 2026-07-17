-- v0.3 场景化推荐包:数据活,每包一组 curated 值(只推荐策展里有白话说明的项,测试强制此约束)
-- 应用走 Core/Packs.lua:LogBulk 整体快照 + 逐条写管线(source=pack),日志页可整体撤销
local ADDON, ns = ...

ns.Data = ns.Data or {}

ns.Data.packs = {
	{ key = "comfort",
	  title = { zh = "晕 3D 舒适", en = "Motion Comfort" },
	  text = { zh = "把随速度和动作晃动镜头的效果全部关掉:驭空术与载具的动态视野、ActionCam 动态俯仰与头部跟随、虚空全屏扭曲。晕 3D 玩家的第一站。",
	    en = "Turns off everything that sways the camera with speed or motion: skyriding and vehicle dynamic FOV, ActionCam dynamic pitch and head bob, and the nether full-screen distortion. First stop for motion-sick players." },
	  values = {
		{ key = "AdvFlyingDynamicFOVEnabled", value = "0" },
		{ key = "DriveDynamicFOVEnabled", value = "0" },
		{ key = "test_cameraDynamicPitch", value = "0" },
		{ key = "test_cameraHeadMovementStrength", value = "0" },
		{ key = "ffxNether", value = "0" },
	  } },
	{ key = "raidperf",
	  title = { zh = "团本性能", en = "Raid Performance" },
	  text = { zh = "只压团本内的画质档位(RAID* 镜像),野外画质不动:天气关闭、阴影最低、粒子 30%、视距 600。开荒 20 人同屏放技能就靠它保帧数。",
	    en = "Only lowers the in-raid quality tier (the RAID* mirrors); open-world visuals stay untouched. Weather off, shadows lowest, particles 30%, view distance 600: this is what holds your framerate with twenty players casting on progression." },
	  values = {
		{ key = "RAIDweatherDensity", value = "0" },
		{ key = "RAIDshadowMode", value = "0" },
		{ key = "RAIDparticleDensity", value = "30" },
		{ key = "RAIDfarclip", value = "600" },
	  } },
	{ key = "pvpinfo",
	  title = { zh = "PvP 信息", en = "PvP Information" },
	  text = { zh = "敌方宠物、图腾、守护者的姓名板全开,姓名板显示距离拉满:拆腾、点名猎人宠、盯法师元素,信息先于操作。",
	    en = "Nameplates for enemy pets, totems and guardians all on, nameplate range maxed: stomp totems, call hunter pets, track mage elementals. Information before execution." },
	  values = {
		{ key = "nameplateShowEnemyPets", value = "1" },
		{ key = "nameplateShowEnemyTotems", value = "1" },
		{ key = "nameplateShowEnemyGuardians", value = "1" },
		{ key = "nameplateMaxDistance", value = "60" },
	  } },
	{ key = "starter",
	  title = { zh = "新手推荐", en = "Starter Picks" },
	  text = { zh = "老玩家装机必改的无争议项:视距倍率拉到引擎上限、目标框仇恨百分比、装备对比 tooltip、大数字千位分隔、幻化来源标注。",
	    en = "The uncontroversial set veterans change on every fresh install: camera distance at the engine cap, threat percentage on the target frame, gear comparison tooltips, thousands separators, and transmog source notes." },
	  values = {
		{ key = "cameraDistanceMaxZoomFactor", value = "2.6" },
		{ key = "threatShowNumeric", value = "1" },
		{ key = "alwaysCompareItems", value = "1" },
		{ key = "breakUpLargeNumbers", value = "1" },
		{ key = "missingTransmogSourceInItemTooltips", value = "1" },
	  } },
}
