local ADDON, ns = ...

local M = {}
ns.PatchWatch = M

function M:OnLogin()
	local version = GetBuildInfo()
	local _, build = GetBuildInfo()
	local g = ns.db.global
	local baseline = g.patchBaseline
	local current = ns.Snapshots:CurrentCvars()

	if not baseline then
		g.patchBaseline = { build = build, version = version, cvars = current }
		return
	end
	if baseline.build == build then return end

	local diff = ns.Snapshots:Diff(baseline.cvars, current)
	if #diff.changed + #diff.added + #diff.removed > 0 then
		g.patchReport = {
			fromVersion = baseline.version,
			toVersion = version,
			fromBuild = baseline.build,
			toBuild = build,
			changed = diff.changed,
			added = diff.added,
			removed = diff.removed,
			t = time(),
			dismissed = false,
		}
	end
	g.patchBaseline = { build = build, version = version, cvars = current }
end
