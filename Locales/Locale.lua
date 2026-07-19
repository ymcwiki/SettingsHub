local ADDON, ns = ...

-- 本地化机制:键即 enUS 原文,缺译回落键本身;zhCN/zhTW 由 Locales/zhCN.lua 覆盖
ns.L = setmetatable({}, { __index = function(_, k) return k end })

ns.L["Possible external takeover"] = "Possible external takeover"
ns.L["Detected %s: %s"] = "Detected %s: %s"

local cjk = GetLocale and (GetLocale() == "zhCN" or GetLocale() == "zhTW")

function ns.IsCJK()
	return cjk and true or false
end

-- 策展描述按客户端语言取 text.zh / text.en(keywords 只进搜索索引,不显示)
function ns.ControlText(control)
	local t = control and control.text
	if not t then return "" end
	if cjk and t.zh and t.zh ~= "" then return t.zh end
	if t.en and t.en ~= "" then return t.en end
	return t.zh or ""
end

-- 行标签 = 描述第一句(zh 按「。:」切;en 按 ". " 或 ": " 切,句内小数点不受影响)
-- 中文标点必须走 plain find:Lua 模式字符类按字节匹配,多字节标点会截断汉字
function ns.ControlLabel(control)
	local s = ns.ControlText(control)
	if s == "" then return control.key or control.id end
	local head
	if cjk then
		local p1 = s:find("。", 1, true)
		local p2 = s:find(":", 1, true)
		local p = (p1 and p2) and math.min(p1, p2) or p1 or p2
		head = p and s:sub(1, p - 1) or s
	else
		head = s:match("^(.-)[%.:] ") or (s:gsub("%.%s*$", ""))
	end
	if head == "" then head = s end
	return head
end
