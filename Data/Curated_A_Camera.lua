-- P4 人工策展定版(初稿来自 scripts/census2lua.py + cvar-census 12.1.0)
-- 文案基准:GetCVarInfo help + 调研报告第六章;census help 错位的条目按领域知识撰写,存疑标 verify
local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.themes = ns.Data.themes or {}

ns.Data.themes[#ns.Data.themes + 1] = {
	key = "A", title = "相机与 ActionCam",
	controls = {
		{ id = "camera.actioncam", type = "composite", version = { added = "7.1.0" },
		  text = { zh = "ActionCam 动态镜头。预设档位是 console 命令(无法回读,按期望态登录重放),下面的精调项是 test_camera* 实验 CVar,版本更新可能被重置,本插件会按期望态补回。", en = { "actioncam", "dynamic camera" } },
		  children = {
			{ id = "camera.actioncam.preset", domain = "consoleexec", key = "actioncam",
			  type = "enum", values = { "off", "basic", "full" }, noReadback = true,
			  valueLabels = { off = "关闭", basic = "基础", full = "完整" },
			  text = { zh = "预设档位。full 一次打开动态俯仰、越肩、目标聚焦全套,再用下面的精调项微调。", en = { "actioncam preset" } } },
			{ id = "camera.actioncam.dynamicPitch", domain = "cvar", key = "test_cameraDynamicPitch", type = "bool", default = "0",
			  text = { zh = "动态俯仰:镜头俯仰角随缩放距离自动调整,视角更接近电影运镜。", en = { "dynamic pitch" } } },
			{ id = "camera.actioncam.pitchBasePad", domain = "cvar", key = "test_cameraDynamicPitchBaseFovPad", type = "number", default = "0.4", range = { 0, 1, 0.05 },
			  text = { zh = "动态俯仰精调:角色脚下保留的屏幕高度比例,越小人物越靠画面底部。", en = { "pitch fov pad" } } },
			{ id = "camera.actioncam.pitchPadFlying", domain = "cvar", key = "test_cameraDynamicPitchBaseFovPadFlying", type = "number", default = "0.75", range = { 0, 1, 0.05 },
			  text = { zh = "动态俯仰精调:飞行时人物保留的屏幕高度比例。", en = { "pitch flying" } } },
			{ id = "camera.actioncam.pitchDownScale", domain = "cvar", key = "test_cameraDynamicPitchBaseFovPadDownScale", type = "number", default = "0.25", range = { 0, 1, 0.05 },
			  text = { zh = "动态俯仰精调:视角朝下看时动态俯仰的强度。", en = { "pitch down scale" } } },
			{ id = "camera.actioncam.overShoulder", domain = "cvar", key = "test_cameraOverShoulder", type = "number", default = "0", range = { -15, 15, 0.5 },
			  text = { zh = "越肩偏移:把人物挪到画面一侧,正值偏左肩视角,负值偏右。第三人称射击游戏式取景。", en = { "over shoulder", "offset" } } },
			{ id = "camera.actioncam.focusEnemy", domain = "cvar", key = "test_cameraTargetFocusEnemyEnable", type = "bool", default = "0",
			  text = { zh = "敌对目标聚焦:选中敌人后镜头自动转向目标,保持其在画面内。", en = { "target focus enemy" } } },
			{ id = "camera.actioncam.focusEnemyPitch", domain = "cvar", key = "test_cameraTargetFocusEnemyStrengthPitch", type = "number", default = "0.4", range = { 0, 1, 0.05 },
			  text = { zh = "敌对聚焦精调:俯仰方向的跟随强度。", en = { "focus pitch strength" } } },
			{ id = "camera.actioncam.focusEnemyYaw", domain = "cvar", key = "test_cameraTargetFocusEnemyStrengthYaw", type = "number", default = "0.5", range = { 0, 1, 0.05 },
			  text = { zh = "敌对聚焦精调:水平方向的跟随强度。", en = { "focus yaw strength" } } },
			{ id = "camera.actioncam.focusInteract", domain = "cvar", key = "test_cameraTargetFocusInteractEnable", type = "bool", default = "0",
			  text = { zh = "互动目标聚焦:与 NPC 对话时镜头转向对方(DialogueUI 类插件的运镜原料)。", en = { "focus interact", "npc dialog camera" } } },
			{ id = "camera.actioncam.headMovement", domain = "cvar", key = "test_cameraHeadMovementStrength", type = "number", default = "0", range = { 0, 2, 0.1 },
			  text = { zh = "头部跟随:镜头轻微跟随人物头部起伏,0 为关闭。晕 3D 者慎开。", en = { "head movement", "head bob" } } },
			{ id = "camera.actioncam.reset", type = "action", run = "reset_test_cvars", confirm = true, buttonText = "一键重置",
			  text = { zh = "一键重置全部 test_* 实验参数(C_CVar.ResetTestCVars),ActionCam 全套回出厂。", en = { "reset actioncam" } } },
		  } },
		{ id = "camera.cameraDistanceMaxZoomFactor", domain = "cvar", key = "cameraDistanceMaxZoomFactor", type = "number", default = "1.9", range = { 1, 2.6, 0.1 },
		  text = { zh = "最大视距倍率。官方滑条上限之外还能再拉远:2.6 是引擎上限,团本开荒看场地的老牌必改项。", en = { "max zoom", "camera distance" } } },
		{ id = "camera.cameraZoomSpeed", domain = "cvar", key = "cameraZoomSpeed", type = "number", default = "20", range = { 1, 50, 1 },
		  text = { zh = "滚轮缩放速度。默认 20 偏慢,拉到 50 滚一格就到位。", en = { "zoom speed" } } },
		{ id = "camera.AdvFlyingDynamicFOVEnabled", domain = "cvar", key = "AdvFlyingDynamicFOVEnabled", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "驭空术滑翔时按速度动态调整视野(速度感拉满)。晕 3D 就关掉。", en = { "skyriding fov", "dynamic fov", "gliding" } } },
		{ id = "camera.DriveDynamicFOVEnabled", domain = "cvar", key = "DriveDynamicFOVEnabled", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "载具驾驶(G.O.A.T. 等)时按速度动态调整视野。", en = { "driving fov", "vehicle" } } },
	},
}
