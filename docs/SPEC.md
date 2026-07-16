# SettingsHub 产品规格 v1

2026-07-16,P1 阶段产出。事实基准:`Dropbox/Addons/sources/2026-07-16-ultimate-settings-addon-research-goals.md`(下称「调研报告」)。未实机验证的结论一律标 `TODO:VERIFY`。

## 1. 定位

Midnight 12.x 原生的游戏内设置中心:全量可搜索、按玩家意图分类、覆盖官方界面有和没有的设置,每一次写入都可撤销,以策展元数据层为长期竞争力。接棒半失修的 AdvancedInterfaceOptions(下称 AIO,1,184 万下载)空出的生态位。与 Leatrix Plus / EnhanceQoL 类 QoL 套件错位:它们做功能,本品做设置的发现、理解、管理与迁移。

## 2. 命名与元数据

**正式名:SettingsHub。** 撞名核验(2026-07-16):经 api.curse.tools 搜索 CurseForge(gameId=1),SettingsHub、OmniSettings、SettingsForge、SettingsCentral 均无结果;同一 API 搜 AdvancedInterfaceOptions 能返回正确条目(slug `advancedinterfaceoptions`,1,184 万下载),证明查询有效。名称格局里最近的是 RaidFrameSettings 与 Account Wide Interface Settings,不构成混淆。

命名空间约定:

- SavedVariables 表名 `SettingsHubDB`
- 官方 Settings 的 setting variable 前缀 `SETTINGSHUB_`(该命名空间全局唯一且永不释放,必须带前缀)
- 允许的全局符号仅三个:`SLASH_SETTINGSHUB1/2` 与 `SettingsHub_OnAddonCompartmentClick`,其余全部走插件私有 namespace

slash 命令:`/settingshub` 为准,`/sh` 为便捷别名(若被先加载的插件占用则放弃别名,不抢占)。子命令:

| 子命令 | 作用 |
|---|---|
| `/sh` | 开关主窗口 |
| `/sh test` | 自测断言组(P2 定义) |
| `/sh dump` | 全量 CVar 落盘到 SavedVariables(P7 元数据管线入口) |
| `/sh undo` | 撤销最近一次写入 |

TOC(P2 落地):

```
## Interface: 120100
## Title: SettingsHub
## Notes: Search, understand, manage and migrate every game setting, exposed or hidden.
## Notes-zhCN: 游戏内设置中心:官方界面有和没有的设置,都在这里发现、理解、管理、迁移。
## Author: Weyk
## Version: @project-version@
## SavedVariables: SettingsHubDB
## AddonCompartmentFunc: SettingsHub_OnAddonCompartmentClick
## IconTexture: Interface\AddOns\SettingsHub\Media\icon
## X-Curse-Project-ID: (发布时填)
## X-Wago-ID: (发布时填)
## X-WoWI-ID: (发布时填)
```

## 3. v1 范围(域矩阵定版)

依据调研报告第七章,逐域判定如下,v1 不再增删:

| 域 | v1 | 说明 |
|---|---|---|
| CVar 引擎 | 纳入 | 全量枚举 + 策展面板,产品主体 |
| 键位绑定 + ModifiedClick | 纳入 | 同一适配器,写后统一 SaveBindings 提交 |
| 宏 | 纳入 | 账号 120 + 角色 30 槽位 |
| EditMode 布局 | 纳入 | 复用官方 Convert*String 序列化,与官方分享串互通 |
| 点击施法 ClickBindings | 纳入 | HasRestrictions 语义实机验证前置(TODO:VERIFY),结论进 docs/VERIFIED.md 后才实现 |
| MuteSoundFile | 纳入 | 仅会话级生效,SavedVariables 存列表登录重放 |
| TTS | 纳入 | C_TTSSettings 读写对称,小适配器 |
| ConsoleExec 重放列表 | 纳入 | 无 getter 命令(actioncam、pitchlimit 类)的通用重放机制 |
| 图形 restart 项 | 纳入 | 9 个 CVar 仅作「需重启」元数据标注,不做特殊管线 |
| 聊天窗口 | 推迟 v2 | 工作量/收益比差 |
| CUF 团队框体 | 排除 | 旧 raid profile API 12.x 已移除,域塌缩,由 CVar + EditMode 覆盖 |

## 4. 功能规格

以下按调研报告目标 G1~G6 展开。未标注者均为 v1 必做;标 [v1.x] 者可延后。

### G1 覆盖

| # | 功能 | 验收标准 |
|---|---|---|
| F1.1 | 全量 CVar 浏览器:ConsoleGetAllCommands 枚举(过滤 commandType 保留 Cvar),逐条 GetCVarInfo 补七元组;打开面板时重枚举回灌 | 实机枚举 ≥1,600 条;登录早期枚举不全的场景(AIO #126 根因之一)被重枚举覆盖 |
| F1.2 | 八大主题策展面板 A~H(相机与 ActionCam / 软目标 / 姓名板 / 战斗浮动文字 / 界面 QoL / 图形画质 / 声音 / 开发者),首发约 85 项 | 85+ 项全部实机可改可撤销,每项有中文白话说明与完整元数据(P4 验收) |
| F1.3 | 七个非 CVar 域适配器(见第 3 节矩阵) | 每域完成「导出、清空或改乱、导入」回环,状态一致(P5 验收) |
| F1.4 | AIO 功能矩阵对齐 | 下表逐项核对通过 |

AIO 对齐清单(调研报告第三章定版):

- 复刻「有」列:开面板全量重枚举、名称与描述文本搜索含命中着色、非默认值高亮、默认值 tooltip、双击行内编辑、combat lockdown 收起编辑框、SetCVar blame 追踪、备份/恢复、带确认的一键全量重置、登录重放
- 补齐「无」列七项:已修改过滤、默认值独立列、单条回默认按钮、写前自动存原值、多备份槽(以 profile 体系实现)、导入导出、角色 profile

### G2 搜索即入口

| # | 功能 | 验收标准 |
|---|---|---|
| F2.1 | 自研全文搜索:预构建 lowercase blob(名称 + 白话描述 + 中英关键词 + 分类路径),多词 AND | 普查清单内任一设置,用中文或英文俗名 3 秒内命中 |
| F2.2 | 过滤词:`tag:modified` `tag:new` `tag:secure` `tag:hidden` | 各过滤视图与实际状态一致(tag:modified 与撤销日志对得上) |
| F2.3 | 打开主窗口即聚焦搜索框 | 打开后直接输入即搜 |
| F2.4 | 官方搜索集成:适合普通玩家的策展子集走 vertical layout 注册,AddSearchTags 加中英同义词 | 官方设置搜索命中本插件注册项 ≥20 个 |
| F2.5 | 官方 Settings canvas 轻入口(跳转按钮;canvas 内容不被官方搜索索引,只当导航) | 从官方设置面板一次点击到达主窗口 |

### G3 信任与安全(对 AIO 的代际差)

| # | 功能 | 验收标准 |
|---|---|---|
| F3.1 | 每次写入前自动记录(旧值/新值/时间/来源)进环形撤销日志 | 任意写入后日志可见对应条目 |
| F3.2 | 单条撤销、单条回默认(GetCVarDefault)、带确认的一键还原暴雪默认 | 普通 CVar 与 secure CVar 各完成一次「写入、撤销、回默认」回环 |
| F3.3 | 只看已修改视图(浏览器过滤 + tag:modified) | 与撤销日志、非默认值高亮三方一致 |
| F3.4 | 卸载即全量回滚:还原本插件改过的全部项 | 卸载流程后抽查改过的项均回到首次触碰前的值 |
| F3.5 | secure/只读徽章;战斗锁定态(secure 行灰化并提示);战斗中写入进 regen 队列且队列可见 | addonCombatRestrictionsForced 模拟战斗下行为正确 |
| F3.6 | SetCVar 返回值逐条检查,失败进汇总清单;禁止 pcall 吞错 | 对只读 CVar 写入能在 UI 看到失败记录 |
| F3.7 | 外部改动 blame:hooksecurefunc + debugstack,UI 展示「最后由 X 修改」 | 用另一插件改 CVar 后 blame 显示正确来源 |

### G4 持久化可靠

| # | 功能 | 验收标准 |
|---|---|---|
| F4.1 | 持久层程序化判定(GetCVarInfo 的 isStoredServerAccount/Character),只重放需要重放的 | 改一个服务器存储 CVar 后重登值仍在(AIO #126 场景) |
| F4.2 | 登录重放 + PLAYER_ENTERING_WORLD 后期再断言 + CVAR_UPDATE 监听外部改动 | 断言发现被覆盖时补写并记日志 |
| F4.3 | Profile 四轴自动切换:角色、专精、设备分辨率、内容场景,各可独立启停 | 四轴各演示一次自动切换且日志可回溯(P6 验收) |
| F4.4 | 导入导出分享串(LibDeflate 压缩);导入前展示 diff(改哪些项、旧值新值),确认后应用 | 导出串在另一角色导入,diff 预览准确,应用后状态一致 |
| F4.5 | EditMode 域复用官方 ConvertLayoutInfoToString / ConvertStringToLayoutInfo,分享串与官方互通 | 官方 EditMode 能导入本插件导出的布局串 |

### G5 元数据策展层(护城河)

| # | 功能 | 验收标准 |
|---|---|---|
| F5.1 | 每个策展项带:白话说明、默认值与取值范围、作用域徽章(账号/角色/本机)、需重载/需重启标签、战斗保护标记、版本变更史 | P4 抽查 10 项,默认值与实机一致,元数据完整 |
| F5.2 | 未策展条目降级展示:运行时枚举的名称、help 原文、七元组徽章 | 浏览器里所有枚举条目均可见可改 |
| F5.3 | L1 管线:`/sh dump` 落盘 + 仓库脚本 diff 上一版,自动产出增删/默认值变化/scope 漂移 review 队列 | 模拟补丁跑通全流程(P7 验收) |
| F5.4 | L2 策展流程:wiki API_changes 页抓取做底稿,人工只写用户可见文案 | docs/MAINTENANCE.md 写明五步例行;小补丁人工 ≤4 小时 |

### G6 Midnight 合规原生

| # | 功能 | 验收标准 |
|---|---|---|
| F6.1 | 零 taint:不写暴雪全局与框体字段;UI 挂官方设置只走 Settings.Register* 注册通道;CVar 读写只走 C_CVar,不碰暴雪 Settings/CVarCallbackRegistry 对象内部 | 全流程 taintLog=2 无本插件条目 |
| F6.2 | 读值路径 issecretvalue 防御(跨暴雪对象边界的值先过守卫) | 开 taintLogObjectSecrets 无 secret 算术报错 |
| F6.3 | 保护操作走 InCombatLockdown 判定 + PLAYER_REGEN_ENABLED 队列 | 战斗模拟下无 ADDON_ACTION_BLOCKED |
| F6.4 | EditMode 直写 C_EditMode,不驱动官方 EditMode UI(taint 重灾区) | EditMode 回环全程 taintLog 干净 |
| F6.5 | 自测基建:`/sh test` 断言组;开发期常开 addon*RestrictionsForced 六件套 + scriptErrors | 每阶段验收前跑一遍全绿 |

## 5. UI 信息架构

主窗口(自绘,ScrollBox 虚拟化保证千条级流畅,Esc 关闭走 UISpecialFrames):

```
搜索框(顶置,打开即聚焦)
├── 浏览器          全量 CVar 表格
├── 主题 A~H        八个策展面板页
├── Profile         四轴规则、profile 管理、导入导出
└── 日志            撤销日志、blame、失败清单、战斗队列
```

浏览器列定义:名称 / 当前值(行内编辑) / 默认值独立列 / 作用域徽章 / secure、只读、需重载标签。非默认值高亮。右键菜单:回默认、复制名称、复制设置命令、加入 profile。

每项 tooltip:当前值、默认值、作用域、最后修改来源、版本注记。

官方 Settings 挂载两条线:

1. canvas 类别一个,内容是打开主窗口的跳转按钮(canvas 不进官方搜索,纯导航价值)
2. vertical layout 子类别,只放面向普通玩家的策展子集(F2.4),不挂全量(避免污染官方搜索与 variable 命名空间)

入口:slash、AddonCompartment。小地图按钮 v1 不做,AddonCompartment 已覆盖「图形入口」需求且零库依赖;若用户反馈强烈列入 v1.x。

## 6. 非目标

原样收录调研报告第十章,越界即返工:

- 不做 QoL 功能大杂烩(与 Leatrix/EQOL 错位)
- 不碰战斗数据与 secret 打击面
- 不做通用配置框架供他插件使用(PeaversConfig 的教训:生态绑定劝退用户)
- v1 不做聊天窗口域
- 不做与原生持久化管线冲突的写入(CDM 图标集合类,EditModeExpanded 的教训)
- 不静默改用户未主动设置的值(Hyperframe 的骂点)

## 7. 版本路线

- v1:P2~P7 全部验收通过,四平台发布(CurseForge / Wago / WoWInterface / GitHub)
- v1.x 候选:聊天窗口域、小地图按钮、策展项从 85 向差集可产品化池(约 600~700)扩充

## 8. 实机验证前置清单

以下结论动到相关模块前必须先实机验证,结果写 docs/VERIFIED.md(源自提示词包附录):

1. C_ClickBindings.SetProfileByInfo 的 HasRestrictions 语义(P5 前置)
2. test_camera* 是否随 config 服务器同步、被 ResetTestCVars/版本更新重置的时机
3. census JSON 默认值与描述逐条对照实机 GetCVarInfo(策展项上线前)
4. 战斗保护 CVar 集合用 GetCVarInfo.isSecure 程序化生成(替代 AIO 手工 65 条表)
5. ConsoleGetAllCommands 中 commandType==Command 的全量命令表落盘,筛可设置化条目
6. addon*RestrictionsForced 六件套除 Chat 外是否跨重启持久
