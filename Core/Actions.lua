local ADDON, ns = ...

-- action 型控件的执行器注册表,Widgets 按 control.run 查找
ns.Actions = {}

function ns.Actions.reset_test_cvars()
	if C_CVar.ResetTestCVars then
		C_CVar.ResetTestCVars()
		ns.Enum:Refresh()
		ns.Print("已重置全部 test_* 实验参数(含 ActionCam 精调)")
	else
		ns.Print("当前客户端没有 C_CVar.ResetTestCVars")
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
	ns.Print("钓鱼预设已应用(互动软目标扇区/距离放宽),日志页可整体撤销")
end
