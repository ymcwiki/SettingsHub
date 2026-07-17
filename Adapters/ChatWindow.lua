local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.chatwindow = M

-- 聊天窗口域(v0.3):十个窗口的名字/字号/颜色/透明度/锁定/停靠/消息组/频道全量快照。
-- SetChatWindow*/Add*/Remove* 写的是 chat-cache,已开的聊天框即时刷新程度未实机验证
-- (VERIFIED.md 第 9 条),恢复后打印 /reload 建议;快照式域,改完要重新捕获

local function numWindows()
	return NUM_CHAT_WINDOWS or 10
end

-- 快照域无单键读写,Engine:Set 不经过这里
function M:Read()
	return nil
end

function M:Apply()
	return false, "bulk-only"
end

function M:Default()
	return nil
end

function M:Serialize()
	if not GetChatWindowInfo then return nil end
	local out = {}
	for i = 1, numWindows() do
		local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
		local messages = { GetChatWindowMessages(i) }
		-- GetChatWindowChannels 返回 name1, id1, name2, id2, ... 只留名字
		local channels = {}
		local raw = { GetChatWindowChannels(i) }
		for j = 1, #raw, 2 do
			channels[#channels + 1] = raw[j]
		end
		out[i] = {
			name = name, size = fontSize,
			r = r, g = g, b = b, alpha = alpha,
			shown = shown and 1 or 0, locked = locked and 1 or 0,
			docked = docked or 0, uninteractable = uninteractable and 1 or 0,
			messages = messages, channels = channels,
		}
	end
	return out
end

function M:Restore(snapshot)
	if InCombatLockdown() then return false, "in-combat" end
	for i = 1, numWindows() do
		local w = snapshot[i]
		if w then
			SetChatWindowName(i, w.name or "")
			SetChatWindowSize(i, w.size or 14)
			SetChatWindowColor(i, w.r or 0, w.g or 0, w.b or 0)
			SetChatWindowAlpha(i, w.alpha or 0)
			SetChatWindowShown(i, w.shown == 1)
			SetChatWindowLocked(i, w.locked == 1)
			SetChatWindowDocked(i, w.docked or 0)
			SetChatWindowUninteractable(i, w.uninteractable == 1)
			-- 消息组与频道:先清现有再按快照重建
			for _, group in ipairs({ GetChatWindowMessages(i) }) do
				RemoveChatWindowMessages(i, group)
			end
			for _, group in ipairs(w.messages or {}) do
				AddChatWindowMessages(i, group)
			end
			local raw = { GetChatWindowChannels(i) }
			for j = 1, #raw, 2 do
				RemoveChatWindowChannel(i, raw[j])
			end
			for _, ch in ipairs(w.channels or {}) do
				AddChatWindowChannel(i, ch)
			end
		end
	end
	ns.Print(ns.L["Chat windows restored; /reload to make every open frame reflect it"])
	return true
end

function M:IsCombatSafe()
	return false
end
