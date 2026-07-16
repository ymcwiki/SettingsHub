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
