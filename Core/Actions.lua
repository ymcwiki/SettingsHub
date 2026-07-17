local ADDON, ns = ...

-- action 型控件的执行器注册表,Widgets 按 control.run 查找
ns.Actions = {}

function ns.Actions.reset_test_cvars()
	if C_CVar.ResetTestCVars then
		C_CVar.ResetTestCVars()
		ns.Enum:Refresh()
		ns.Print(ns.L["All test_* experimental CVars reset (incl. ActionCam fine-tuning)"])
	else
		ns.Print(ns.L["This client has no C_CVar.ResetTestCVars"])
	end
end

-- 钓鱼预设:放宽互动软目标的距离与扇区,让浮漂不用对准也能按互动键收竿
-- 数值组合 TODO:VERIFY(对标 Advanced Soft Target 的常用值),实机确认前 UI 隐藏
function ns.Actions.fishing_preset()
	local sets = {
		SoftTargetInteractArc = "2",
		SoftTargetInteractRange = "15",
		SoftTargetNameplateInteract = "1",
	}
	for k, v in pairs(sets) do
		ns.Engine:Set("cvar", k, v, "user")
	end
	ns.Print(ns.L["Fishing preset applied (interaction soft-target arc/range widened); undo it as a whole from the Log page"])
end
