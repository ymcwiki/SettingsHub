-- v0.3 人工策展定版。聊天类差集:官方聊天设置只覆盖气泡/亵渎过滤等少数,这些全是隐藏项
-- Chat*Volume 三件套疑为语音聊天时的音量压低(ducking)倍率,标 verify 待实机确认
local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.themes = ns.Data.themes or {}

ns.Data.themes[#ns.Data.themes + 1] = {
	key = "I", title = "Chat",
	controls = {
		{ id = "chat.chatMouseScroll", domain = "cvar", key = "chatMouseScroll", type = "bool", default = "1",
		  text = { zh = "鼠标滚轮翻聊天记录。",
		    en = "Scroll chat history with the mouse wheel.",
		    keywords = { "chat scroll", "mouse wheel" } } },
		{ id = "chat.colorChatNamesByClass", domain = "cvar", key = "colorChatNamesByClass", type = "bool", default = "0", officialSearch = true,
		  text = { zh = "聊天里的玩家名字按职业着色,一次全频道生效。官方只提供逐频道右键开关,这是那套操作的全局总闸。",
		    en = "Color player names in chat by class, all channels at once. The official UI only offers a per-channel right-click toggle; this is the global switch behind it.",
		    keywords = { "class color", "chat names" } } },
		{ id = "chat.wholeChatWindowClickable", domain = "cvar", key = "wholeChatWindowClickable", type = "bool", default = "1",
		  text = { zh = "整个聊天窗口区域都响应点击。关掉后只有文字本身可点,窗口空白处点击穿透到世界。",
		    en = "The whole chat window area responds to clicks. Turn it off and only the text itself is clickable; empty window space clicks through to the world.",
		    keywords = { "chat clickable", "click through" } } },
		{ id = "chat.synchronizeChatFrames", domain = "cvar", key = "synchronizeChatFrames", type = "bool", default = "1",
		  text = { zh = "聊天窗口布局随服务器同步,换机器登录跟着走。想每台机器各留一套就关掉。",
		    en = "Sync chat window layout to the server so it follows you across machines. Turn it off to keep a separate setup per machine.",
		    keywords = { "chat sync", "synchronize" } } },
		{ id = "chat.showToastConversation", domain = "cvar", key = "showToastConversation", type = "bool", default = "1",
		  text = { zh = "收到密语对话时弹右下角 toast 通知。",
		    en = "Pop a toast notification for incoming whisper conversations.",
		    keywords = { "whisper toast", "notification" } } },
		{ id = "chat.ChatAmbienceVolume", domain = "cvar", key = "ChatAmbienceVolume", type = "number", default = "0.3", range = { 0, 1, 0.05 }, verify = true,
		  text = { zh = "语音聊天进行时,环境音压低到的倍率。TODO:VERIFY 压低语义待实机确认。",
		    en = "Volume multiplier ambience ducks to while voice chat is active. TODO:VERIFY ducking semantics pending in-game confirmation.",
		    keywords = { "voice chat ducking", "ambience" } } },
		{ id = "chat.ChatMusicVolume", domain = "cvar", key = "ChatMusicVolume", type = "number", default = "0.3", range = { 0, 1, 0.05 }, verify = true,
		  text = { zh = "语音聊天进行时,音乐压低到的倍率。TODO:VERIFY 同上。",
		    en = "Volume multiplier music ducks to while voice chat is active. TODO:VERIFY same as above.",
		    keywords = { "voice chat music" } } },
		{ id = "chat.ChatSoundVolume", domain = "cvar", key = "ChatSoundVolume", type = "number", default = "0.4", range = { 0, 1, 0.05 }, verify = true,
		  text = { zh = "语音聊天进行时,音效压低到的倍率。TODO:VERIFY 同上。",
		    en = "Volume multiplier sound effects duck to while voice chat is active. TODO:VERIFY same as above.",
		    keywords = { "voice chat sound" } } },
	},
}
