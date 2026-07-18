# SettingsHub

![SettingsHub](docs/assets/banner-1280x640.png)

魔兽世界 Midnight (12.1+) 的游戏内设置中心:官方界面有和没有的设置,都在这里发现、理解、管理、迁移。

接棒半失修的 AdvancedInterfaceOptions(AIO)空出的生态位。与 Leatrix Plus / EnhanceQoL 这类 QoL 套件不冲突:它们做功能,SettingsHub 做设置本身的发现、理解、管理与迁移。

## 功能

- **发现页**:打开插件先看到的不是表格,是按你当前设置给出的主动建议(可一键处理)、按意图组织的引导(晕 3D、帧数低、玩治疗、打 PvP……每条内联控件当场改)、近期补丁新增设置一览
- **试穿模式**:推荐包可以先试 10 分钟,到期或登出自动还原,满意再转常驻
- **全量 CVar 浏览器**:运行时枚举 1,600+ 条,名称/描述/中英俗名全文搜索,`tag:modified` `tag:new` `tag:secure` `tag:hidden` 过滤词,类别侧栏,行内编辑,非默认值高亮,默认值独立列
- **十一个策展主题面板**:相机与 ActionCam、软目标、姓名板、战斗浮动文字、界面 QoL、图形画质(含 RAID* 副本档位)、声音、开发者合规面板、聊天、手柄与光标、任务与地图。每项有中英双语白话说明、取值范围、作用域徽章、版本注记
- **场景化推荐包**:晕 3D 舒适 / 团本性能 / PvP 信息 / 新手推荐四个一键设置组,应用前预览差异,应用后可整包撤销
- **中英双语**:UI 与 140+ 条策展说明都有 enUS 和 zhCN/zhTW 两套文案,按客户端语言自动选择;搜索不分语言,中英俗名甚至拼音(xingmingban)都命中
- **每一次写入都可撤销**:写前自动记录进 500 条环形日志,单条撤销、单条回默认、一键还原为改动前、一键回暴雪默认(双确认),卸载可全量回滚
- **命名快照**:全量 CVar 现状一键落盘(上限 10 份),任意两份或与当前值对比(值变/新增/删除/scope/secure 五类),勾选值变项选择性恢复,恢复同样可撤销。改乱了回得去,补丁前后一比就知道暴雪动了什么
- **持久化可靠**:登录重放 + 进入世界二次断言 + CVAR_UPDATE 监听,根治 AIO #126 的「设置不保存」;外部插件改动带 blame 追踪(最后由谁改的)
- **冲突检测**:同一项被同一外部来源跨 3 个登录反复覆盖时,日志页亮出冲突条目,一键选择「停止管理」或「保持我的值」,不再和别的插件无限拉锯而不自知
- **八个非 CVar 域**:键位+ModifiedClick、宏、EditMode 布局(与官方分享串互通)、点击施法、声音静音列表、TTS、console 命令重放、聊天窗口布局
- **Profile 四轴自动切换**:按内容场景(地城/团本/竞技场/战场/野外)、专精、分辨率、角色,固定优先级,离开上下文默认提示而非静默改动
- **导入导出**:`!SH1!` 分享串(LibSerialize + LibDeflate),导入前逐项 diff 预览确认
- **Midnight 合规**:零 taint 设计,不写暴雪全局与框体字段,CVar 只走 C_CVar,secure 项战斗锁定入队

## 快速上手

| 命令 | 作用 |
|---|---|
| `/sh` 或 `/settingshub` | 开关主窗口(打开即聚焦搜索框) |
| `/sh test` | 自测断言组(枚举/写撤销回环/重放存活) |
| `/sh dump` | 全量 CVar 落盘,供元数据管线 diff |
| `/sh undo` | 撤销最近一次写入 |

官方设置(Esc)里也有两个入口:SettingsHub canvas 页(跳转按钮)和「SettingsHub 精选」(20+ 项策展设置直接进官方搜索)。

## 从 AIO 迁移

1. 记录你在 AIO 里改过的项:AIO 没有「已修改过滤」,如果记不全,装好 SettingsHub 后用浏览器页的非默认值高亮排查即可(所有非默认项一目了然)
2. 卸载 AIO(其 EnforceSettings 若开着,先关,避免登录时互相覆盖同一 CVar)
3. 装 SettingsHub,浏览器页搜 `tag:modified` 查看当前全部非默认项
4. 对要长期保持的项:右键该行,选「把当前值记入激活 profile」,登录重放就会守住它
5. AIO 的手动备份槽对应这里的 profile 体系(Profile 页),备份/恢复/多套切换都在那里

功能对照:AIO 有的(全量枚举/搜索/非默认高亮/blame/一键重置/登录重放)这里都有;AIO 没有的(已修改过滤、默认值列、单条回默认、写前自动存原值、多 profile、导入导出、角色级设置、四轴自动切换)是本插件的主要增量。

## 前置与异常处理

- 依赖全部内嵌(AceDB-3.0 / LibSerialize / LibDeflate),无外部前置
- **战斗中**:secure 项(姓名板距离等)灰化锁定,写入自动排队,脱战生效,日志页可见队列
- **写入静默失败**(只读/非法值/战斗中 secure):11.2 起客户端不报错,本插件逐条检查返回值,失败项进日志页失败清单,不会假装成功
- **设置重登丢了**:先看日志页 blame(是否别的插件在覆盖),再确认该项已记入 profile(期望态才会被重放);服务器存储项由「进入世界二次断言」兜底补写
- **主题页有些项看不到**:标注 TODO:VERIFY 的项在实机验证前刻意隐藏,清单见 docs/VERIFIED.md

## 开发

- 无头测试:`python3 -m pip install -r requirements-dev.txt` 后运行 `python3 tests/run_headless.py`(用 Lua 5.1 运行时跑全部引擎断言,不需要游戏客户端;Windows/Linux 均由 CI 验证)
- 元数据管线:游戏内 `/sh dump` 后跑 `scripts/dump_diff.py <SV路径>` 产出 review 队列;`scripts/wiki_apichanges.py 12.1.0` 抓 wiki 变更底稿;流程见 docs/MAINTENANCE.md
- 发布:推 `v*` tag,GitHub Actions 经 BigWigs packager 发 CurseForge/Wago/WoWInterface(需配置对应 secrets)

## 文档

- docs/SPEC.md 产品规格(功能与验收标准)
- docs/ARCH.md 架构设计(数据模型/适配器/写管线/SV schema)
- docs/TESTING.md 无游戏环境的自动测试范围与实机边界
- docs/VERIFIED.md 实机验证台账(哪些结论还没验证、怎么验证)
- docs/MAINTENANCE.md 每补丁维护五步(预算:小补丁 4 小时内)
