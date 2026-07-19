# CurseForge 项目页描述(粘贴用)

改版或换文案时,把下面内容贴进项目页 Description(编辑器支持 markdown 粘贴后调格式)。
GitHub 链接已填真实仓库地址。本文案对应 v0.7.0 的界面结构。

---

**SettingsHub** is an in-game settings hub for Midnight (12.x): every setting the game has, in one window, whether the default Options UI exposes it or not.

AdvancedInterfaceOptions has not been updated for Midnight. SettingsHub is a from-scratch replacement built for the 12.x API rules, and it goes further than AIO ever did: plain-language explanations for most settings, a doctor that tells you why a setting does nothing, patch-change reports, undo for every write, profiles, snapshots and import/export.

## One window, organized by topic

The sidebar is a single list of tabs: Discover, All Settings, Favorites, then about twenty topic tabs (Camera & View, Nameplates, Graphics & Quality, Sound & Voice, Quests & Maps, Action Bars, Accessibility and so on), and the tools: Recommended Packs, Profiles & Migration, Snapshots, Log & Restore.

Each topic page has two parts. At the top, curated picks: the settings worth knowing about, each with a plain-language explanation, sane ranges and real controls (sliders for numbers, dropdowns for choices). Below that, the complete list of every setting in that topic. All 1,600+ console variables are reachable this way; nothing is hidden in a dump you have to know the name of.

The look is a clean flat dark UI, not the stock dialog-box style.

## Explanations you can actually trust

About 87% of all settings have a description, and every description says where it came from: verified by hand in game, taken from community documentation, or inferred from naming patterns. Settings nobody has documented are honestly labeled as such. Hover any row and the tooltip shows the explanation, current value, default, scope, when the setting was added, and which addon last changed it.

## When a setting refuses to work

You set a value, nothing changes. Usually another addon owns that behavior: Plater or a nameplate addon, ElvUI, Leatrix Plus, a map addon, a bar addon. SettingsHub detects the usual suspects among your loaded addons and tells you right on the setting: the value is fine, change it in that addon instead. Read-only detection, it never touches your configuration.

## Know what a patch changed

On login after a client update, SettingsHub compares your settings against the last build and lists exactly what changed: values, additions, removals. One click opens the snapshot page to compare and restore. No more "something feels off since the patch" guesswork.

## Start with Discover

The Discover page reads your current values and makes suggestions you can apply or dismiss in one click: armor foley sounds still on, view distance not raised, a forgotten debug flag. It also collects the most-wanted hidden settings (max camera zoom, spell queue window, nameplate distance and friends), intent guides for common situations (motion sickness, low FPS, healing, PvP, recording, gamepad, fresh install), and settings added in recent patches.

## Recommended packs, with a fitting room

Four one-click bundles: Motion Comfort, Raid Performance, PvP Information, Starter Picks. Every apply shows a preview first and lands as a single undo entry, so a whole pack rolls back in one click. Not sure? Try it for 10 minutes: it applies temporarily, reverts by itself when the timer runs out or you log off, and one click makes it permanent if you like it.

## Every change can be taken back

- Every write is logged first: old value, new value, time, source
- Undo any entry, reset any item to its default, or restore everything to the state before SettingsHub touched it
- Uninstalling can roll back every change the addon ever made
- Failed writes (read-only, invalid, combat-locked) are reported, never swallowed
- Secure values queue during combat and apply when you leave it

## Snapshots, conflicts, and settings that stick

- Save the full state of all settings in one click, up to 10 named snapshots stamped with the game build; diff any two and restore selected rows
- When another addon keeps overwriting a value you manage, it gets named after three separate logins, with two one-click resolutions: stop managing that value, or keep yours
- Values you pin are replayed at login and re-asserted after loading screens, with a "last changed by" record

## Beyond CVars

Key bindings and modified clicks, macros, Edit Mode layouts, click bindings, muted sound files, text-to-speech settings, and chat window layouts are all part of a profile. Profiles switch automatically on four axes (instance type, specialization, resolution, character) and export as compact `!SH1!` strings with a full change preview before anything is applied. Only the parts you check are exported and imported.

## Search

Multi-word search over names, descriptions and keywords, in English and Chinese at once, plus pinyin for Chinese terms. Filters: `tag:modified`, `tag:new`, `tag:secure`, `tag:hidden`, `tag:favorite`. Typing anywhere jumps to All Settings with results.

## Commands

- `/sh` or `/settingshub` opens the window
- `/sh undo` undoes the last write
- `/sh diag` prints a full diagnostic report (strictly read-only); paste it into a bug report and it usually answers everything

A draggable minimap button opens the window too.

## Notes

- Zero-taint by design: CVar access goes through C_CVar only, and the default Settings panel is only touched through the official registration API
- Diagnostics and self-tests never modify your configuration
- Fully localized in English and Chinese (Simplified/Traditional); the UI and all explanations follow your client language
- Bug reports and requests: https://github.com/ymcwiki/SettingsHub or the comments below
