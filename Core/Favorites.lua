local ADDON, ns = ...

-- 账号级收藏(书签语义):只读写 db.global.favorites 一张表。
-- 不写 CVar、不进期望态(profile.cvar)、不占撤销环、不随 profile 切换。
local M = {}
ns.Favorites = M

local function store()
	return ns.db and ns.db.global and ns.db.global.favorites
end

function M:IsFavorite(key)
	local s = store()
	return (s ~= nil and s[key] == true) or false
end

-- 返回切换后的状态:true=已收藏,false=已取消
function M:Toggle(key)
	local s = store()
	if not s or type(key) ~= "string" or key == "" then return false end
	if s[key] then
		s[key] = nil
	else
		s[key] = true
	end
	return s[key] == true
end

function M:Count()
	local s, n = store(), 0
	if s then
		for _, enabled in pairs(s) do
			if enabled == true then n = n + 1 end
		end
	end
	return n
end

-- 排序后的收藏键列表;可能含别的客户端收藏的键,展示层自行按 Enum 过滤
function M:List()
	local s, out = store(), {}
	if s then
		for k, enabled in pairs(s) do
			if enabled == true then out[#out + 1] = k end
		end
	end
	table.sort(out)
	return out
end
