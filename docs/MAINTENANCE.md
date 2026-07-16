# 维护手册

调研结论:断更两个补丁,元数据过时反而变负资产。L1 自动化是卖点可持续的前提。
预算:小补丁人工 4 小时内,大版本(X.0.0)预留 1 到 2 天。

## 每补丁例行五步

1. **存废 diff**:PTR 或正式服上线当天,游戏内 `/sh dump`,退出后跑
   `python3 scripts/dump_diff.py <WTF/Account/<账号>/SavedVariables/SettingsHubDB.lua>`,
   得 `dumps/review-<build>.md`。新增/删除清单先过一遍:删除项要查 Data/ 策展数据和自己 profile 的引用。
2. **默认值 diff**:review 队列「默认值变化」节,逐条决定要不要在条目 `version.changed`
   里加「X.Y 起默认值变更」注记;census JSON 同步回写。
3. **scope 漂移**:review 队列「scope 漂移」节。影响两处:作用域徽章显示、重放判定。
   wiki 底稿(`python3 scripts/wiki_apichanges.py <版本号>`)的自由文本节里常有官方说明,对照着读。
4. **Settings API 面检查**:官方 Blizzard_ImplementationReadme.lua 与 Settings.Register* 签名
   有没有动(大版本高发)。Integration/OfficialSettings.lua 是唯一触点。
5. **战斗保护清单抽验**:review 队列「secure 漂移」节 + 游戏内开
   `addonCombatRestrictionsForced 1` 抽验三五个 secure 项的锁定态 UI 正确。

全部处理完:更新 TOC `## Interface:` 版本号,跑一遍 `/sh test`,发版。

## 数据回写约定

- review 队列每条勾掉前决定三件事:进不进策展(Data/Curated_*.lua)、census JSON 回不回写、加不加版本注记
- 策展新条目:文案基准是实机 help + wiki 底稿,census 里 help 有错位前科,以实机为准
- 存疑一律 `verify = true` + TODO:VERIFY 注释,UI 自动隐藏,验证后解除(台账在 docs/VERIFIED.md)

## 发布流程

1. 更新 CHANGELOG.md
2. `git tag v<版本>` 并推送 tag,GitHub Actions 自动跑 BigWigs packager v2,
   产物发 GitHub Release + CurseForge + Wago + WoWInterface
3. 仓库 secrets 需要:`CF_API_KEY`、`WAGO_API_TOKEN`、`WOWI_API_TOKEN`(GITHUB_TOKEN 自带);
   TOC 里 `X-Curse-Project-ID` / `X-Wago-ID` / `X-WoWI-ID` 首次在各平台建项目后填入
4. 本地手工打包(不经 CI):`python3 scripts/package.py v0.1.0`,产物在 dist/

## 大版本(X.0.0)额外动作

- CVar 大换血预期(12.0.0 实测增 137 删 153):review 队列会很长,先处理「删除」防报错,再处理新增
- 官方 Settings 框架源码 diff 一遍(wow-ui-source 镜像),重点 Blizzard_Settings* 目录
- floatingCombatText 式的家族改名(_v2 前科)按「删除+新增」成对识别,策展数据整组迁移
