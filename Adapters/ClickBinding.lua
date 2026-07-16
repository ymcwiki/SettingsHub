local ADDON, ns = ...

ns.Adapters = ns.Adapters or {}
local M = {}
ns.Adapters.clickbinding = M

-- TODO:VERIFY C_ClickBindings.SetProfileByInfo 的 HasRestrictions 语义(战斗禁写?
-- 需硬件事件?)尚未实机验证,结论出来前一律按战斗不安全处理,详见 docs/VERIFIED.md

function M:Read()
	local infos = C_ClickBindings.GetProfileInfo()
	return infos and #infos or 0
end

function M:Apply(_, infos)
	if InCombatLockdown() then return false, "in-combat" end
	C_ClickBindings.SetProfileByInfo(infos)
	return true
end

function M:Default()
	return nil
end

-- macro 类条目按宏名存(槽位号跨角色不稳定),导入时按名字重映射回索引
function M:Serialize()
	local infos = C_ClickBindings.GetProfileInfo()
	if not infos then return nil end
	local out = {}
	for _, info in ipairs(infos) do
		local e = {
			type = info.type, actionID = info.actionID,
			button = info.button, modifiers = info.modifiers,
		}
		if info.type == Enum.ClickBindingType.Macro then
			local name = GetMacroInfo(info.actionID)
			e.macroName = name
		end
		out[#out + 1] = e
	end
	return out
end

function M:Restore(snapshot)
	if InCombatLockdown() then return false, "in-combat" end
	if not snapshot then return false, "empty" end
	local infos, skipped = {}, {}
	for _, e in ipairs(snapshot) do
		local actionID = e.actionID
		if e.macroName then
			actionID = GetMacroIndexByName(e.macroName)
			if actionID == 0 then
				skipped[#skipped + 1] = e.macroName
				actionID = nil
			end
		end
		if actionID then
			infos[#infos + 1] = {
				type = e.type, actionID = actionID,
				button = e.button, modifiers = e.modifiers,
			}
		end
	end
	C_ClickBindings.SetProfileByInfo(infos)
	if #skipped > 0 then
		ns.Print("点击施法导入:以下宏不存在,对应绑定已跳过: " .. table.concat(skipped, ", "))
	end
	return true, #skipped
end

function M:IsCombatSafe()
	return false
end
