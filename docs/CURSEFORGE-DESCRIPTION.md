# CurseForge 项目页描述(粘贴用)

首次建项目或改版时,把下面内容贴进项目页 Description(编辑器支持 markdown 粘贴后调格式)。
GitHub 链接已填真实仓库地址。

---

**SettingsHub** is an in-game settings hub for Midnight (12.1+): every setting the game has, in one searchable window, whether the default UI exposes it or not.

AdvancedInterfaceOptions has not been updated for Midnight. SettingsHub is a from-scratch replacement built for the 12.x API rules, and it covers the parts AIO never had: a modified-only view, per-change undo, character profiles, and import/export.

## Browse everything

- Live enumeration of all 1,600+ console variables, refreshed every time you open the window
- Inline editing, a separate default-value column, non-default values highlighted
- Scope badges (account / character / this PC), secure and read-only flags
- Right-click any row: reset to default, copy name, copy the /console command, pin into your profile
- Tooltips show current value, default, scope, patch notes, and which addon last changed the value

## Find it in seconds

- Multi-word search over names, help text and curated keywords
- Filters: `tag:modified`, `tag:new`, `tag:secure`, `tag:hidden`
- Category sidebar with counts
- 20+ curated toggles are also registered into the default Settings search (Esc menu)

## Curated panels

Eight themed pages with plain-language explanations, sane ranges and patch annotations: Camera and ActionCam (with presets and fine tuning), soft targeting, nameplates (including the 12.1 additions), floating combat text, interface QoL, graphics (raid-specific mirrors included), sound, and a developer page that doubles as an addon-compliance test panel.

## Every change can be taken back

- Every write is logged first: old value, new value, time, source
- Undo any entry, reset any item to its Blizzard default, or restore everything to the state before SettingsHub touched it
- Uninstalling can roll back every change the addon ever made
- Failed writes (read-only, invalid, combat-locked) are reported, never swallowed

## Named snapshots

- Save the full state of all 1,600+ CVars in one click (up to 10 snapshots, named and stamped with the game build)
- Diff any snapshot against your live values or against another snapshot: value changes, additions, removals, scope and secure-flag drift
- Check the rows you want and restore them selectively; every restored value goes through the normal write pipeline, so it is undoable too
- Take one before and after a patch and see exactly what Blizzard changed

## Conflict detection

- When another addon keeps overwriting a value you manage, SettingsHub notices: three overwrites on separate logins flag it as a conflict
- The Log page shows who is fighting you and how often, with two one-click resolutions: stop managing that value, or keep yours and let the replay keep winning

## Settings that actually stick

- Values you pin are replayed at login and re-asserted after loading screens
- External overwrites are detected and corrected, with a "last changed by" record
- Secure CVars queue during combat and apply when you leave it

## Beyond CVars

Key bindings and modified clicks, macros (imported by name, slot drift reported), Edit Mode layouts (uses the official share-string format), click bindings, muted sound files, text-to-speech settings, and a replay list for console-only commands like `actioncam`.

## Profiles and migration

- Automatic profile switching on four axes: instance type (dungeon/raid/arena/battleground/world), specialization, screen resolution, character
- Leaving a context asks before reverting; it never silently overwrites your manual tweaks
- Export/import as compact `!SH1!` strings, with a full change preview before anything is applied

## Commands

- `/sh` or `/settingshub` opens the window (search box focused)
- `/sh undo` undoes the last write
- `/sh test` runs the built-in self test

## Notes

- Zero-taint by design: CVar access goes through C_CVar only, and the default Settings panel is only touched through the official registration API
- Localized in English and Chinese (Simplified/Traditional): the UI and all curated explanations follow your client language, and search matches both languages either way
- Bug reports and requests: https://github.com/ymcwiki/SettingsHub or the comments below

---

**简体中文**:SettingsHub 是 Midnight (12.1+) 的游戏内设置中心,界面与全部策展说明中英双语。全量 CVar 浏览器加八个白话说明的主题面板,官方界面没放出来的隐藏设置也在内;每一次写入先记日志,单条可撤销、可整体还原、卸载可回滚;命名快照全量备份当前设置,补丁前后对比、勾选恢复;别的插件反复覆盖你的设置会被记名点出,一键处置;键位、宏、EditMode 布局、点击施法、静音列表、TTS 一并纳入 profile,支持按副本类型/专精/分辨率/角色四轴自动切换,导入导出带 diff 预览。反馈请到 https://github.com/ymcwiki/SettingsHub 或下方评论。
