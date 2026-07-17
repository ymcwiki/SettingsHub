# 实机验收清单

代码侧(无头测试、语法、数据完整性)已全部通过;本清单是各阶段验收里必须在游戏内完成的部分。
安装:解压 dist/SettingsHub-*.zip,把 SettingsHub/ 放进 `Interface/AddOns/`,重启客户端或 /reload。

预期会有磨合:UI 代码在无游戏客户端的环境只做了编译级检查,首次实机加载如遇模板名/API 签名报错属预期内的修正循环,把 `/console scriptErrors 1` 打开,报错截图发回即可。

## P2 骨架 + 引擎

- [ ] 加载无报错(scriptErrors 1 开着进游戏)
- [ ] `/sh test`:枚举 ≥1,600、普通与 secure CVar 写/撤销/回默认六项全 PASS
- [ ] 按提示重登,再跑 `/sh test`,第三组「重放存活」PASS
- [ ] `/console taintLog 2` + `/console addonCombatRestrictionsForced 1` 走一遍主流程,Logs/taint.log 无本插件条目

## P3 浏览器 + 搜索 + 信任 UI

- [ ] `/sh` 打开主窗口,搜索框已聚焦;用中文或英文俗名(如「视距」「raw mouse」)3 秒内搜到目标项
- [ ] `tag:modified` 结果与日志页撤销记录对得上
- [ ] 行内编辑一个值,非默认高亮出现;右键回默认,高亮消失
- [ ] addonCombatRestrictionsForced 1 模拟战斗:secure 行灰化,编辑值入队,关掉后队列应用
- [ ] 开着主窗口打一场副本,无卡顿无报错(ScrollBox 虚拟化验证)

## P4 策展面板

- [ ] 八个主题页逐页过:每项可改可撤销,tooltip 有当前/默认/作用域/版本注记
- [ ] 抽查 10 项默认值与 tooltip 显示一致(实机 GetCVarInfo 口径)
- [ ] scriptProfile 打开后出现「待重载」标记和「重载界面生效」按钮
- [ ] Esc 官方设置搜「盔甲」「raw mouse」「威胁」等,能命中 SettingsHub 精选注册项(目标 ≥20 项可被搜到)
- [ ] ActionCam 复合项:预设 full、精调、一键重置各来一遍

## P5 非 CVar 域

- [ ] Profile 页勾选各域,「捕获勾选域的当前状态」,导出串;改乱(挪键位/删宏/换 EditMode 布局)后导入,状态回来
- [ ] 宏导入后若报槽位漂移,检查动作条按钮
- [ ] G 声音页底部:添加一个 fileID 静音,重登后仍静音;临时解除本次生效
- [ ] ClickBindings:按 docs/VERIFIED.md 第 1 条的步骤验证 HasRestrictions 语义,结论回写台账
- [ ] 全程 taintLog 干净

## P6 Profile 四轴

- [ ] 四轴各演示一次自动切换(进本/换专精/改分辨率/换角色),日志页能回溯每次切换的整域快照
- [ ] 离开上下文时弹提示(默认 prompt),选「是」回落基准 profile
- [ ] 导出串发到另一角色导入:diff 预览准确,应用后状态一致
- [ ] 战斗中切 profile:secure 项入队,脱战补齐

## P7 管线与发布

- [ ] 游戏内 `/sh dump`,退出后 `python3 scripts/dump_diff.py <SV路径>` 产出基准入库;改天再 dump 一次验证 review 队列
- [ ] `python3 scripts/wiki_apichanges.py 12.1.0` 正常出底稿(已在 Linux 侧实测通过)
- [ ] GitHub 仓库建好后配 secrets,推 v0.1.0 tag,四平台产物出包
- [ ] 找个没用过的号照 README「从 AIO 迁移」走一遍,10 分钟内完成

## VERIFIED.md 台账(8 项 UNVERIFIED)

验收过程中顺手做,每条验完把状态改 CONFIRMED/REFUTED:
ClickBindings 语义、test_camera* 同步时机、census 默认值抽查、secure 集合计数、
Command 命令表落盘、restrictionsForced 持久性、钓鱼预设数值、D/F/G 存疑项。

## v0.2 国际化 / 快照 / 冲突

**T1 enUS 本地化**

- [ ] enUS 客户端(或 `SET textLocale "enUS"`)进游戏:主窗口、八主题页、Profile 页、快照页、日志页、各弹窗与聊天消息无中文残留
- [ ] zhCN 客户端回归:以上界面仍是中文,观感与 v0.1 一致
- [ ] 任一语言下,中文俗名(视距)和英文俗名(raw mouse)都能搜到目标项
- [ ] 官方设置(Esc)搜索:enUS 客户端下用英文关键词命中「SettingsHub Picks」注册项

**T2 命名快照(快照页)**

- [ ] 新建快照,浏览器页改乱 20 项,快照页点「对比」:值变数量与改动一致
- [ ] 勾选其中一部分「恢复勾选项」:值回到快照,再到日志页逐条撤销,恢复前状态可回
- [ ] 建满 10 份后再建:弹确认,同意后最旧一份被淘汰
- [ ] 补丁演练(等 12.2 时顺手做):两个 build 各存一份,对比能列出版本间新增/删除/默认值变化

**T3 冲突检测(日志页冲突区)**

- [ ] 用一个会持续 SetCVar 的插件(或写 3 行测试插件每次登录覆盖某 CVar),同一项在 SettingsHub 里记入期望态,重登 3 次后冲突区出现条目,插件名与次数正确
- [ ] 「停止管理」:该项移出期望态,再重登不再补写、条目消失
- [ ] 「保持我的值」:条目消失但仍每次登录改回;再覆盖 3 个登录后条目重新出现

## v0.3 推荐包 / 策展扩容 / 聊天域 / 拼音

**推荐包页**

- [ ] 四个包逐个「预览并应用」:预览列出的差异与实际写入一致,聊天框有逐条明细
- [ ] 应用后到日志页找到该包的整域快照条目,撤销后所有值回到应用前
- [ ] 战斗中应用含 secure 项的包(PvP 信息):secure 项入队,脱战补齐
- [ ] 重复应用同一包:提示「与当前值完全一致」,不产生新日志条目

**新策展主题(I 聊天 / J 手柄与光标 / K 任务与地图)**

- [ ] 三个新主题页逐项过:可改可撤销,tooltip 完整;J 主题接手柄抽查 3 项生效
- [ ] 抽查 10 项默认值与实机 GetCVarInfo 一致(census 种子口径复核)
- [ ] verify 隐藏项(Chat*Volume 三件套)按 VERIFIED.md 第 10 条验证后解除
- [ ] GamePad 数值项范围按 VERIFIED.md 第 11 条实测回写

**聊天窗口域**

- [ ] Profile 页勾选聊天窗口域并捕获;改乱窗口(改名/挪频道/换字号)后应用 profile,快照回来
- [ ] 观察恢复后已开窗口的即时刷新程度,按 VERIFIED.md 第 9 条回写结论
- [ ] 导出串带聊天窗口域,另一角色导入后布局一致

**拼音搜索**

- [ ] 搜索框输 xingmingban 命中姓名板系列;输 ruanmubiao 命中软目标系列
- [ ] 首字母缩写(如 xmb)能命中对应项
