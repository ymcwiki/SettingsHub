local ADDON, ns = ...

-- v0.4.1 内部错误自检:自家入口(事件/命令/控件回调/监听器)统一 xpcall 包装。
-- 出错:记入会话表 + SV 环(上限 20,跨 /reload 保留),聊天框每种错误提示一次,/sh diag 可看全文。
-- 只记录与提示,不吞语义:SPEC G6 禁的是吞 SetCVar 返回值,这里是防错误静默消失。
local M = { session = {}, seen = {} }
ns.Errors = M

local MAX = 20

function M:Record(msg, stack)
	local entry = { t = time(), msg = tostring(msg), stack = stack and tostring(stack):sub(1, 600) or "" }
	self.session[#self.session + 1] = entry
	local s = ns.db and ns.db.global.luaErrors
	if s then
		s[#s + 1] = entry
		while #s > MAX do
			table.remove(s, 1)
		end
	end
	local head = entry.msg:match("[^\n]+") or entry.msg
	if not self.seen[head] then
		self.seen[head] = true
		ns.Print(string.format(ns.L["Internal error recorded: %s (details in /sh diag)"], head))
	end
end

local function onError(err)
	M:Record(err, debugstack and debugstack(3, 10, 2))
	return err
end

-- 包一个函数:错误被记录与提示,调用方继续活着(UI 点击、事件分发不因单点错误全灭)
function ns.Guard(fn)
	return function(...)
		local args, n = { ... }, select("#", ...)
		local ok, ret = xpcall(function()
			return fn(unpack(args, 1, n))
		end, onError)
		if ok then return ret end
	end
end
