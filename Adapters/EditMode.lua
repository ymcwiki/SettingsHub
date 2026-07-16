local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.editmode = M

-- 只直写 C_EditMode,绝不驱动官方 EditMode UI(taint 重灾区);
-- 序列化复用官方 ConvertLayoutInfoToString,导出串与官方分享串互通;出战斗才应用

function M:Read()
	local layouts = C_EditMode.GetLayouts()
	return layouts and layouts.activeLayout
end

function M:Apply(_, layoutIndex)
	if InCombatLockdown() then return false, "in-combat" end
	C_EditMode.SetActiveLayout(tonumber(layoutIndex))
	return true
end

function M:Default()
	return nil
end

function M:Serialize()
	local layouts = C_EditMode.GetLayouts()
	if not layouts then return nil end
	local out = { active = layouts.activeLayout, layouts = {} }
	for _, l in ipairs(layouts.layouts) do
		if l.layoutType ~= Enum.EditModeLayoutType.Preset then
			out.layouts[#out.layouts + 1] = {
				name = l.layoutName,
				character = l.layoutType == Enum.EditModeLayoutType.Character or nil,
				str = C_EditMode.ConvertLayoutInfoToString(l),
			}
		end
	end
	return out
end

-- 按名字合并:同名布局覆盖,新名字追加;完成后一次 SaveLayouts 提交
function M:Restore(snapshot)
	if InCombatLockdown() then return false, "in-combat" end
	if not snapshot or not snapshot.layouts then return false, "empty" end
	local layouts = C_EditMode.GetLayouts()
	local byName = {}
	for i, l in ipairs(layouts.layouts) do
		if l.layoutType ~= Enum.EditModeLayoutType.Preset then byName[l.layoutName] = i end
	end
	for _, saved in ipairs(snapshot.layouts) do
		local info = C_EditMode.ConvertStringToLayoutInfo(saved.str)
		if info then
			info.layoutName = saved.name
			info.layoutType = saved.character and Enum.EditModeLayoutType.Character
				or Enum.EditModeLayoutType.Account
			local i = byName[saved.name]
			if i then
				layouts.layouts[i] = info
			else
				layouts.layouts[#layouts.layouts + 1] = info
				byName[saved.name] = #layouts.layouts
			end
		end
	end
	C_EditMode.SaveLayouts(layouts)
	if snapshot.active then
		C_EditMode.SetActiveLayout(snapshot.active)
	end
	return true
end

function M:IsCombatSafe()
	return false
end
