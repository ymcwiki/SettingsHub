-- 控件类型判定与策展 CVar 索引。纯逻辑层,不依赖 UI。
local ADDON, ns = ...

local INTERNAL_RULES = {
	{ mode = "contains", value = "tutorial" },
	{ mode = "pattern", value = "^last.+" },
	{ mode = "pattern", value = "filters$" },
	{ mode = "contains", value = "viewed" },
	{ mode = "contains", value = "reminder" },
	{ mode = "pattern", value = "cache$" },
	{ mode = "contains", value = "closedinfoframes" },
}

local BINARY_TEXT = { ["0"] = true, ["1"] = true }

ns.Data = ns.Data or {}

local curatedByKey = {}
local function indexControls(controls)
	for _, control in ipairs(controls or {}) do
		if control.domain == "cvar" and control.key
			and control.type ~= "action" and not control.verify then
			curatedByKey[control.key] = control
		end
		if control.children then indexControls(control.children) end
	end
end

for _, theme in ipairs(ns.Data.themes or {}) do
	indexControls(theme.controls)
end
ns.Data.CuratedByKey = curatedByKey

local function stepFor(text)
	return tostring(text):find(".", 1, true) and 0.1 or 1
end

function ns.ControlKind(key, info)
	local control = key ~= nil and curatedByKey[key] or nil
	if control then
		local params = { control = control }
		if control.type == "bool" then
			return "toggle", params
		elseif control.type == "number" then
			if control.range then
				params.range = control.range
				return "slider", params
			end
			params.step = stepFor(control.default)
			return "stepper", params
		elseif control.type == "enum" then
			params.values = control.values
			params.valueLabels = control.valueLabels
			return "enum", params
		elseif control.type == "string" then
			return "input", params
		end
		return "input", params
	end

	local safeInfo = type(info) == "table" and info or {}
	local defaultText = tostring(safeInfo.default)
	local valueText = tostring(safeInfo.value)
	if BINARY_TEXT[defaultText] and BINARY_TEXT[valueText] then
		return "toggle", {}
	end

	local numericText
	if tonumber(defaultText) ~= nil then
		numericText = defaultText
	elseif tonumber(valueText) ~= nil then
		numericText = valueText
	end
	if numericText then
		return "stepper", { step = stepFor(numericText) }
	end
	return "input", {}
end

local function containsSeenWord(key)
	local words = tostring(key or "")
	words = words:gsub("(%l)(%u)", "%1 %2")
	words = words:gsub("(%u)(%u%l)", "%1 %2")
	words = words:gsub("[^%a]+", " ")
	words = " " .. words:lower() .. " "
	return words:find(" seen ", 1, true) ~= nil
end

function ns.ControlKind_IsInternalState(key)
	local lowered = tostring(key or ""):lower()
	for _, rule in ipairs(INTERNAL_RULES) do
		if rule.mode == "contains" then
			if lowered:find(rule.value, 1, true) then return true end
		elseif lowered:match(rule.value) then
			return true
		end
	end
	return containsSeenWord(key)
end
