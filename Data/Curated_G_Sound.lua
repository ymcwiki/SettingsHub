-- P4 人工策展定版。census 内该主题 help 多处错位,文案按已知语义撰写
local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.themes = ns.Data.themes or {}

ns.Data.themes[#ns.Data.themes + 1] = {
	key = "G", title = "声音",
	controls = {
		{ id = "sound.Sound_EnableArmorFoleySoundForSelf", domain = "cvar", key = "Sound_EnableArmorFoleySoundForSelf", type = "bool", default = "1", officialSearch = true, version = { added = "12.0.0" },
		  text = { zh = "自己角色移动时的盔甲摩擦/碰撞音。12.0 引入后社区呼声最高的「怎么关」项之一。", en = { "armor foley", "armor sound" } } },
		{ id = "sound.Sound_EnableArmorFoleySoundForOthers", domain = "cvar", key = "Sound_EnableArmorFoleySoundForOthers", type = "bool", default = "1", officialSearch = true, version = { added = "12.0.0" },
		  text = { zh = "其他玩家的盔甲摩擦音。人多的主城关掉世界清净。", en = { "armor foley others" } } },
		{ id = "sound.FootstepSounds", domain = "cvar", key = "FootstepSounds", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "脚步声开关。", en = { "footstep sounds" } } },
		{ id = "sound.Sound_ListenerAtCharacter", domain = "cvar", key = "Sound_ListenerAtCharacter", type = "bool", default = "1", officialSearch = true,
		  text = { zh = "声音听者位置在角色身上;关闭则以镜头为听者,拉远后声音也跟着远。", en = { "listener position", "audio camera" } } },
		{ id = "sound.Sound_AlternateListener", domain = "cvar", key = "Sound_AlternateListener", type = "bool", default = "1",
		  text = { zh = "听者朝向只用镜头水平角计算(替代完整朝向),某些环绕声设置下定位更稳。", en = { "alternate listener" } } },
		{ id = "sound.Sound_EnableDSPEffects", domain = "cvar", key = "Sound_EnableDSPEffects", type = "bool", default = "1",
		  text = { zh = "环境 DSP 音效(山洞混响等)。", en = { "dsp effects", "reverb" } } },
		{ id = "sound.Sound_DSPBufferSize", domain = "cvar", key = "Sound_DSPBufferSize", type = "number", default = "0", verify = true,
		  text = { zh = "声音缓冲区大小,0 为系统默认。爆音/杂音时可尝试调整。TODO:VERIFY 合法取值与需否重启待实机确认。", en = { "dsp buffer", "audio crackling" } } },
		{ id = "sound.Sound_OutputSampleRate", domain = "cvar", key = "Sound_OutputSampleRate", type = "enum", default = "44100", requiresRestart = true, verify = true,
		  values = { "44100", "48000", "96000" },
		  text = { zh = "输出采样率。TODO:VERIFY 生效是否需要重启声音系统待实机确认。", en = { "sample rate" } } },
	},
}
