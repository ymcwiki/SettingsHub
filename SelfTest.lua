local ADDON, ns = ...
local L = ns.L

local M = {}
ns.SelfTest = M

local SECURE_CANDIDATES = { "nameplateMaxDistance", "nameplateOtherTopInset" }
local SERVER_CANDIDATES = { "alwaysCompareItems", "breakUpLargeNumbers", "autoLootDefault" }

local results

local function check(name, ok, detail)
	results[#results + 1] = { name = name, ok = ok and true or false, detail = detail }
end

local function report()
	local pass, fail = 0, 0
	for _, r in ipairs(results) do
		if r.ok then
			pass = pass + 1
			print(string.format("|cff00ff00PASS|r %s", r.name))
		else
			fail = fail + 1
			print(string.format("|cffff0000FAIL|r %s%s", r.name, r.detail and (" [" .. tostring(r.detail) .. "]") or ""))
		end
	end
	ns.Print(string.format(L["Self-test done: %d passed / %d failed"], pass, fail))
	if fail == 0 then
		ns.Print(L["Compliance reminder: re-run the main flows with /console taintLog 2 and addonCombatRestrictionsForced 1"])
	end
	return fail == 0
end

-- 写入、撤销、回默认三步回环;结束后把值与期望态都恢复到进入前的状态
local function roundtrip(label, key, target)
	local info = ns.Enum:Get(key)
	if not info then
		check(label .. L[": exists"], false, key .. L[" not found"])
		return
	end
	local old = ns.Adapters.cvar:Read(key)
	local prevDesired = ns.db.profile.cvar[key]

	local r = ns.Engine:Set("cvar", key, target, "test")
	check(label .. L[": write"], r == "applied" and ns.Adapters.cvar:Read(key) == target,
		string.format("r=%s cur=%s want=%s", tostring(r), tostring(ns.Adapters.cvar:Read(key)), tostring(target)))

	local entry = ns.Engine:LastEntry()
	r = ns.Engine:Undo(entry)
	check(label .. L[": undo"], r == "applied" and ns.Adapters.cvar:Read(key) == old,
		string.format("cur=%s want=%s", tostring(ns.Adapters.cvar:Read(key)), tostring(old)))

	r = ns.Engine:ResetToDefault("cvar", key)
	local def = ns.Adapters.cvar:Default(key)
	check(label .. L[": reset to default"], r == "applied" and ns.Adapters.cvar:Read(key) == def,
		string.format("cur=%s def=%s", tostring(ns.Adapters.cvar:Read(key)), tostring(def)))

	if ns.Adapters.cvar:Read(key) ~= old then
		ns.Engine:Set("cvar", key, old, "test")
	end
	ns.db.profile.cvar[key] = prevDesired
end

local function pickSecure()
	for _, key in ipairs(SECURE_CANDIDATES) do
		local info = ns.Enum:Get(key)
		if info and info.secure and not info.readonly then return key end
	end
	for key, info in pairs(ns.Enum.cache) do
		if info.secure and not info.readonly and tonumber(info.value) then return key end
	end
end

local function pickServerStored()
	for _, key in ipairs(SERVER_CANDIDATES) do
		local info = ns.Enum:Get(key)
		if info and (info.serverAccount or info.serverCharacter) and not info.readonly
			and (info.value == "0" or info.value == "1") then
			return key
		end
	end
end

-- 第三组跨重登:phase A 写标记后需要重登,phase B 验证值存活并复原
local function replaySurvival()
	local marker = ns.db.global.selftest
	if marker then
		local cur = ns.Adapters.cvar:Read(marker.key)
		check(string.format(L["replay survival: %s still %s after relog"], marker.key, marker.want), cur == marker.want,
			string.format("cur=%s", tostring(cur)))
		ns.Engine:Set("cvar", marker.key, marker.old, "test")
		ns.db.profile.cvar[marker.key] = nil
		ns.db.global.selftest = nil
		ns.Print(L["Third group done, test value restored"])
	else
		local key = pickServerStored()
		if not key then
			check(L["replay survival: find a server-stored candidate"], false, L["no candidate available"])
			return
		end
		local old = ns.Adapters.cvar:Read(key)
		local want = old == "1" and "0" or "1"
		local r = ns.Engine:Set("cvar", key, want, "test")
		if r == "applied" then
			ns.db.global.selftest = { key = key, old = old, want = want, t = time() }
			ns.Print(string.format(L["Third group staged: %s set to %s. Relog, then run /sh test again to finish"], key, want))
		else
			check(L["replay survival: staging write"], false, key .. L[" write failed"])
		end
	end
end

function M:Run()
	results = {}

	local ok, n = ns.Enum:Refresh()
	check(string.format(L["enum: >=1600 (got %s)"], tostring(n)), ok and n >= 1600, not ok and n or nil)

	roundtrip(L["normal CVar"] .. "(cameraZoomSpeed)", "cameraZoomSpeed",
		ns.Adapters.cvar:Read("cameraZoomSpeed") == "1" and "1.5" or "1")

	if InCombatLockdown() then
		check(L["secure CVar: must run out of combat"], false, L["currently in combat"])
	else
		local skey = pickSecure()
		if skey then
			local cur = ns.Adapters.cvar:Read(skey)
			roundtrip(L["secure CVar"] .. "(" .. skey .. ")", skey, cur == "41" and "40" or "41")
		else
			check(L["secure CVar: find a candidate"], false, L["no usable secure value"])
		end
	end

	replaySurvival()

	return report()
end

-- /sh diag:一条命令收全诊断证据,弹窗展示,一张截图带走
-- 内容:环境状态、写管线回环(pcall 捕获错误文本)、全策展项可写性扫描(写回当前值,零副作用)
local diagFrame

local function showDiag(text)
	-- 无头测试环境没有 UIParent,只打印
	if not UIParent then
		print(text)
		return
	end
	if not diagFrame then
		diagFrame = CreateFrame("Frame", "SettingsHubDiagFrame", UIParent, "BackdropTemplate")
		diagFrame:SetSize(720, 420)
		diagFrame:SetPoint("CENTER")
		diagFrame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})
		diagFrame:SetMovable(true)
		diagFrame:EnableMouse(true)
		diagFrame:RegisterForDrag("LeftButton")
		diagFrame:SetScript("OnDragStart", diagFrame.StartMoving)
		diagFrame:SetScript("OnDragStop", diagFrame.StopMovingOrSizing)
		diagFrame:SetFrameStrata("DIALOG")
		tinsert(UISpecialFrames, "SettingsHubDiagFrame")
		local close = CreateFrame("Button", nil, diagFrame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -6, -6)
		local sf = CreateFrame("ScrollFrame", nil, diagFrame, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 14, -32)
		sf:SetPoint("BOTTOMRIGHT", -32, 14)
		local eb = CreateFrame("EditBox", nil, sf)
		eb:SetMultiLine(true)
		eb:SetFontObject(ChatFontNormal)
		eb:SetWidth(660)
		eb:SetAutoFocus(false)
		eb:SetScript("OnEscapePressed", function() diagFrame:Hide() end)
		eb:SetScript("OnTextChanged", function(self) self:SetText(self.diagText or "") end)
		sf:SetScrollChild(eb)
		diagFrame.editBox = eb
	end
	diagFrame.editBox.diagText = text
	diagFrame.editBox:SetText(text)
	diagFrame:Show()
end

function M:Diag()
	local lines = {}
	local function add(fmt, ...)
		lines[#lines + 1] = string.format(fmt, ...)
	end
	local ver, build = GetBuildInfo()
	local addonVer = "?"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		addonVer = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
	end
	add("SettingsHub diag  client=%s(%s)  addon=%s  locale=%s", tostring(ver), tostring(build), addonVer, tostring(GetLocale()))
	add("db=%s  enum=%d  combatLock=%s  inCombat=%s  scriptErrors=%s",
		ns.db and "ok" or "NIL", ns.Enum.count or -1,
		tostring(ns.UI and ns.UI.combatLocked), tostring(InCombatLockdown()),
		tostring(C_CVar.GetCVar("scriptErrors")))
	-- 枚举链路逐层:API 存在性、原始命令数、匹配的 Cvar 型条数
	local rawCmds = ConsoleGetAllCommands and ConsoleGetAllCommands() or nil
	local cvarType = Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
	local matched = 0
	for i = 1, rawCmds and #rawCmds or 0 do
		if rawCmds[i].commandType == cvarType then matched = matched + 1 end
	end
	add("enumChain: AreCVarsLoaded=%s  rawCommands=%s  cvarTypeMatched=%d",
		C_CVar.AreCVarsLoaded and tostring(C_CVar.AreCVarsLoaded()) or "MISSING",
		rawCmds and tostring(#rawCmds) or "NO-API", matched)

	-- 写管线回环:与勾选框同一条链路(少了鼠标事件层),错误全文捕获
	local okPipe, errPipe = pcall(function()
		local key = "cameraZoomSpeed"
		local old = ns.Adapters.cvar:Read(key)
		assert(old ~= nil, "cameraZoomSpeed unreadable")
		local r, e = ns.Engine:Set("cvar", key, old == "20" and "21" or "20", "test")
		assert(r == "applied", "Set=" .. tostring(r) .. " err=" .. tostring(e))
		assert(ns.Engine:UndoLast() == "applied", "UndoLast failed")
	end)
	add("pipeline=%s%s", okPipe and "OK" or "ERROR", okPipe and "" or ("  " .. tostring(errPipe)))

	-- 全策展项可写性扫描:把当前值原样写回,拒绝写入的记名(blame 有 _selfWriting 保护)
	local rejected, missing, secureSkip, tested = {}, 0, 0, 0
	local function walk(controls)
		for _, c in ipairs(controls) do
			if c.domain == "cvar" and c.key then
				local cur = ns.Adapters.cvar:Read(c.key)
				local info = ns.Enum:Get(c.key)
				if cur == nil then
					missing = missing + 1
				elseif info and info.secure and InCombatLockdown() then
					secureSkip = secureSkip + 1
				else
					tested = tested + 1
					ns.Engine._selfWriting = true
					local okw = C_CVar.SetCVar(c.key, cur)
					ns.Engine._selfWriting = false
					if not okw then rejected[#rejected + 1] = c.key end
				end
			end
			if c.children then walk(c.children) end
		end
	end
	for _, th in ipairs(ns.Data.themes or {}) do
		walk(th.controls)
	end
	add("sweep: tested=%d missing=%d secureSkip=%d rejected=%d", tested, missing, secureSkip, #rejected)
	if #rejected > 0 then
		add("rejected: %s", table.concat(rejected, "  "))
	end

	-- 本次会话失败清单尾部
	add("failures=%d", #ns.Engine.failures)
	for i = math.max(1, #ns.Engine.failures - 4), #ns.Engine.failures do
		local fl = ns.Engine.failures[i]
		if fl then
			add("  fail [%s] %s=%s err=%s", tostring(fl.source), tostring(fl.key), tostring(fl.value), tostring(fl.err))
		end
	end

	local text = table.concat(lines, "\n")
	showDiag(text)
	ns.Print(ns.L["Diag done: screenshot the window and send it back"])
	return lines
end

-- /sh probe:鼠标焦点链 + 当前页首个勾选行的几何/状态 + 程序化点击回环
-- 用法:鼠标悬停在问题控件上,聊天框输入 /sh probe 回车(打字期间鼠标别动)
function M:Probe()
	local foci
	if GetMouseFoci then
		foci = GetMouseFoci()
	elseif GetMouseFocus then
		foci = { GetMouseFocus() }
	end
	local names = {}
	for _, f in ipairs(foci or {}) do
		names[#names + 1] = f.GetDebugName and f:GetDebugName() or tostring(f)
	end
	ns.Print("mouse over: " .. (#names > 0 and table.concat(names, "  >  ") or "(none)"))

	local key = ns.UI and ns.UI.currentPageKey
	local page = key and ns.UI.pages[key]
	local pf = page and page.frame
	local row
	for _, w in ipairs(pf and pf.widgets or {}) do
		if w.check then row = w break end
	end
	if not row then
		ns.Print("probe: current page has no checkbox row (open a theme page first)")
		return
	end
	local function rect(f)
		return string.format("L=%.0f B=%.0f W=%.0f H=%.0f lvl=%d strata=%s mouse=%s shown=%s",
			f:GetLeft() or -1, f:GetBottom() or -1, f:GetWidth() or -1, f:GetHeight() or -1,
			f:GetFrameLevel(), f:GetFrameStrata(), tostring(f:IsMouseEnabled()), tostring(f:IsVisible()))
	end
	ns.Print("row1:   " .. rect(row))
	ns.Print("check1: " .. rect(row.check) .. "  enabled=" .. tostring(row.check:IsEnabled()))
	if GetCursorPosition then
		local cx, cy = GetCursorPosition()
		local es = row.check:GetEffectiveScale()
		ns.Print(string.format("cursor(check-space): x=%.0f y=%.0f  scale=%.2f", cx / es, cy / es, es))
	end
	-- 程序化点击两次:验证 OnClick 处理器与写管线(净效果为零)
	local v0 = row.check:GetChecked()
	row.check:Click()
	local v1 = row.check:GetChecked()
	row.check:Click()
	ns.Print(string.format("click test: %s -> %s -> %s", tostring(v0), tostring(v1), tostring(row.check:GetChecked())))
end

-- P7 元数据管线入口:全量落盘供仓库脚本 diff
function M:Dump()
	local ok, n = ns.Enum:Refresh()
	if not ok then
		ns.Print(L["CVars not fully loaded yet, try again in a moment"])
		return
	end
	local cvars = {}
	for name, e in pairs(ns.Enum.cache) do
		cvars[name] = {
			d = e.default,
			a = e.serverAccount and 1 or nil,
			c = e.serverCharacter and 1 or nil,
			s = e.secure and 1 or nil,
			r = e.readonly and 1 or nil,
			h = e.help ~= "" and e.help or nil,
		}
	end
	local _, build = GetBuildInfo()
	ns.db.global.dump = { t = time(), build = build, version = (GetBuildInfo()), count = n, cvars = cvars }
	ns.Print(string.format(L["Dumped %d CVars to SavedVariables (SettingsHubDB.global.dump); readable by repo scripts after you exit the game"], n))
end
