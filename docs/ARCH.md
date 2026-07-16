# SettingsHub 架构设计 v1

2026-07-16,P1 阶段产出。配套阅读 docs/SPEC.md。硬约束(零 taint、写入必查返回值、写前记日志、pending 显式建模、变量带前缀)见 SPEC 第 4 节 G6 与提示词包 P0,此处不重复。

## 1. 模块总览与目录结构

仓库根即插件根(packager 约定),docs/ 与 scripts/ 经 .pkgmeta 排除出发布包:

```
SettingsHub/
├── SettingsHub.toc
├── Libs/                  LibStub, CallbackHandler-1.0, AceDB-3.0, LibSerialize, LibDeflate
├── Core/
│   ├── Engine.lua         统一写管线、撤销环、baseline 表、失败清单
│   ├── Enum.lua           CVar 枚举与七元组缓存
│   ├── Replay.lua         登录重放、后期断言
│   ├── Blame.lua          外部改动追踪(hooksecurefunc + debugstack)
│   ├── CombatQueue.lua    战斗锁定写入队列
│   └── Profiles.lua       四轴切换器、导入导出
├── Adapters/
│   ├── Cvar.lua  Binding.lua  Macro.lua  EditMode.lua
│   ├── ClickBinding.lua  MuteSound.lua  TTS.lua  ConsoleExec.lua
│   └── ReplayList.lua     无回读重放型的共享基类(MuteSound/ConsoleExec 继承)
├── Data/
│   ├── Curated_A_Camera.lua ... Curated_H_Dev.lua   八大主题策展定义
│   └── (由 scripts/census2lua.py 从 cvar-census 生成骨架,人工填文案)
├── UI/
│   ├── MainFrame.lua  Browser.lua  ThemePage.lua  ProfilePage.lua  LogPage.lua
│   ├── Search.lua         blob 索引构建与查询
│   └── Widgets.lua        控件工厂(type 到控件的映射)
├── Integration/
│   └── OfficialSettings.lua   canvas 入口 + vertical 子集注册
├── SelfTest.lua           /sh test 断言组、/sh dump
├── scripts/               census 转换、dump diff(Python,不进发布包)
└── docs/                  SPEC / ARCH / VERIFIED / MAINTENANCE
```

## 2. 声明式数据模型

一份 control 定义推导全部行为:UI 渲染、搜索索引、已修改计数、reload-pending、战斗锁定、官方注册。控件代码不写业务分支,只消费字段。

### 2.1 control 字段

| 字段 | 类型 | 说明 | 消费方 |
|---|---|---|---|
| `id` | string | 稳定标识,点分分类路径(如 `camera.actioncam.dynamicPitch`),前缀即分类树 | 分类树、搜索、profile |
| `domain` | string | 适配器路由:`cvar / binding / macro / editmode / clickbinding / mutesound / tts / consoleexec` | Engine |
| `key` | string | 域内主键(CVar 名、绑定 action 名等);composite/action 无 | 适配器 |
| `type` | string | `bool / number / enum / string / composite / action` | Widgets |
| `default` | any | 静态种子;CVar 域运行时被 GetCVarInfo 覆盖(L0 权威) | 已修改计数、回默认 |
| `range` / `values` | table | number 的 {min,max,step};enum 的取值表 | Widgets |
| `text.zh` | string | 白话说明:改了会发生什么、适合谁 | UI、搜索 blob |
| `text.en` | table | 英文同义关键词 | 搜索 blob、AddSearchTags |
| `scope` | string | `account / character / machine`;CVar 域运行时由七元组判定覆盖 | 徽章、重放判定 |
| `secure` / `readonly` | bool | 运行时覆盖 | 战斗锁定、徽章 |
| `requiresReload` / `requiresRestart` | bool | 显式建模,不靠猜 | pending 标记、Reload 按钮 |
| `version` | table | `{added="12.1.0", changed={{patch, note}}}` | tooltip 版本注记、tag:new |
| `visibleWhen` / `parent` | func/id | 联动显隐谓词(eqol 模式) | Widgets |
| `children` | table | composite 的子控件数组,每个自身是完整 control | Widgets |
| `noReadback` | bool | 无 getter 域(consoleexec):按期望态记录,UI 明示无法回读校验 | UI、重放 |
| `confirm` | bool | action 执行前确认框 | Widgets |
| `officialSearch` | bool | 是否注册进官方 vertical layout | Integration |
| `run` | string | action 的执行器名(注册表查找,不存函数) | Engine |

### 2.2 两级条目

- **策展级**:Data/ 里手写的约 85 项,字段齐全。
- **生成级**:浏览器里其余枚举条目,运行时由 Enum.lua 从 ConsoleGetAllCommands + GetCVarInfo 合成最小 control(id=`browser.<name>`、domain=cvar、text.zh=help 原文、七元组回填 scope/secure/readonly/default),不落盘。策展与否只影响元数据丰富度,写管线与撤销完全一致。

静态种子与实机不一致时以实机为准,差异记入 review 队列回写 census(SPEC F5.1 验收口径)。

### 2.3 表达力自证:最简与最复杂

最简布尔 CVar,三行有效字段:

```lua
{ id = "qol.rawMouseEnable", domain = "cvar", key = "rawMouseEnable", type = "bool",
  text = { zh = "原始鼠标输入。绕过系统指针加速,镜头漂移或手感不一致时开这个。",
           en = { "raw mouse", "mouse acceleration" } } }
```

最复杂复合项,ActionCam 预设加精调加重置,三种 domain 混合:

```lua
{ id = "camera.actioncam", type = "composite",
  text = { zh = "ActionCam 动态镜头。预设是 console 命令,精调是 test_camera* 实验 CVar。",
           en = { "actioncam", "dynamic camera" } },
  version = { added = "7.1.0" },
  children = {
    { id = "camera.actioncam.preset", domain = "consoleexec", key = "actioncam",
      type = "enum", values = { "off", "basic", "full" }, noReadback = true,
      text = { zh = "预设档位。命令无法回读,按期望态记录并登录重放。", en = { "preset" } } },
    { id = "camera.actioncam.dynamicPitch", domain = "cvar", key = "test_cameraDynamicPitch",
      type = "bool", text = { zh = "动态俯仰:镜头随移动自动调整角度。", en = { "dynamic pitch" } } },
    -- 越肩偏移、目标聚焦、头部跟随等同构子项,略
    { id = "camera.actioncam.reset", type = "action", run = "reset_test_cvars", confirm = true,
      text = { zh = "一键重置全部 test_camera* 参数(C_CVar.ResetTestCVars)。", en = { "reset" } } },
  } }
```

### 2.4 派生规则

- **渲染**:Widgets 按 `type` 查控件工厂;composite 渲染成组框,children 递归。
- **搜索 blob**:`lower(id路径 + key + text.zh + concat(text.en) + 分类显示名)`,数据加载与枚举回灌后重建;`tag:` 过滤词是谓词,先筛后扫。
- **已修改计数**:适配器 Read() 与 default 比对,聚合到分类树节点。
- **pending**:requiresReload 且值已改,进 pending 集,UI 标记加 Reload 按钮;重载后值即生效,集合自然清空。
- **战斗锁定**:secure 且 InCombatLockdown 时行灰化,写入转队列。
- **官方注册**:officialSearch 为真的项由 Integration 在 PLAYER_LOGIN 注册 vertical 条目,变量名 `SETTINGSHUB_<id>`,AddSearchTags(text.en 加中文名)。

## 3. 适配器层

统一接口,Engine 只认接口不认实现:

```lua
-- Adapter 接口
--   Read(key)            -> value|nil     读当前值;noReadback 域返回记录的期望态
--   Apply(key, value)    -> ok, err       纯写入,不记日志(日志在 Engine 统一做)
--   Serialize(opts)      -> snapshot      域全量导出,opts 可选子集
--   Restore(snapshot)    -> report        按快照回灌,逐条走 Engine 写管线
--   IsCombatSafe(key)    -> bool          战斗中能否立即写
```

实现共八个文件。提示词包「七个适配器」的口径按类别数:MuteSound 与 ConsoleExec 同属无回读重放型,共享 ReplayList 基类,算一类两实现。

| 适配器 | 后端 API | 持久层 | 战斗限制 | 特殊点 |
|---|---|---|---|---|
| Cvar | C_CVar 全家 | Config.wtf 或服务器(七元组判定) | 仅 secure 项战斗锁写 | 写后查返回值;blame;重放断言 |
| Binding | SetBinding* + SaveBindings(GetCurrentBindingSet());ModifiedClick 同路提交 | 服务器端绑定集 | 全部 nocombat | 键位与 ModifiedClick 合一 |
| Macro | CreateMacro/EditMacro/DeleteMacro | 服务器槽位,账号 120 + 角色 30 | 建改删 nocombat | 导入按名字重映射,槽位漂移显式提示 |
| EditMode | C_EditMode.GetLayouts/SaveLayouts/SetActiveLayout | 服务器端 | 出战斗才应用 | 直写 C_EditMode 不驱动官方 UI;Convert*String 与官方分享串互通 |
| ClickBinding | C_ClickBindings.Get/SetProfileByInfo | 引擎侧角色级 | TODO:VERIFY(HasRestrictions 语义,VERIFIED.md 前置) | macro 类绑定按宏名重映射 |
| MuteSound | MuteSoundFile/UnmuteSoundFile | 无,仅会话级 | 无 | SV 存 fileID 列表登录重放;支持临时解除 |
| TTS | C_TTSSettings | 账号/角色随 CVar TTSUseCharacterSettings | 无 | 读写对称 |
| ConsoleExec | ConsoleExec | 无 getter,多数不持久 | 无标注 | fire-and-forget,UI 明示无法回读 |

## 4. CVar 引擎与写管线

所有写入(UI 手动、profile 切换、导入、重放、撤销)走同一条管线,顺序固定:

1. 调用 `Engine:Set(domain, key, value, source)`
2. secure 且 InCombatLockdown:入 CombatQueue(按 key 去重,后写覆盖),UI 显示队列态,返回
3. 首次触碰该 key:记 `baseline["<domain>:<key>"] = 当前值`
4. 追加撤销环条目 `{ t, domain, key, old, new, source }`
5. `adapter.Apply(key, value)`,检查返回值;失败则条目标 failed(不计入已修改),进失败清单
6. 成功:刷新 UI;该 key 若注册了官方 setting,调 Settings.NotifyUpdate 让官方面板同步

`source` 取值:`user / profile:<name> / import / replay / undo / uninstall`。

撤销语义分四档,全部经同一管线:

- 单条撤销:写回该条目的 old(source=undo)
- 单条回默认:写 GetCVarDefault(name)
- 一键全量还原:遍历 baseline 逐条写回,带确认(IRREVERSIBLE 文案)
- 卸载还原:同全量还原,随后清空 SavedVariables

撤销环 500 条定长,旧条目被覆盖。baseline 表独立于环存在:环解决「最近改错了退回去」,baseline 解决「全量还原与卸载需要首次触碰前的原值」,环淘汰不影响还原能力。

枚举(Enum.lua):C_CVar.AreCVarsLoaded 为真后才首次枚举;每次打开主窗口重枚举回灌(登录早期枚举不全,AIO #126 根因之一)。缓存在内存,不落 SV。

重放(Replay.lua):登录时应用 active profile 的 cvar 表(按七元组只重放需要的:machine 项存 Config.wtf 免重放,服务器存储项写一遍防后到同步覆盖),加 mutesound 与 consoleexec 全量;PLAYER_ENTERING_WORLD 后期对期望态做 diff 断言,不一致补写并记日志(source=replay)。这是对 AIO #126「一次性早期重放」缺陷的根治。

Blame(Blame.lua):hooksecurefunc C_CVar.SetCVar,debugstack 抽调用方文件与行号(AIO 已验证该方案),写 `blame[key] = {by, t}`;CVAR_UPDATE 兜底捕获非 SetCVar 路径的变化(服务器同步等)。hook 只观察不拦截,无 taint 传染。

## 5. SavedVariables schema

AceDB-3.0,表名 SettingsHubDB。角色轴即 AceDB 内建的 per-char profileKeys,不另造轮子。

```lua
SettingsHubDB = {
  global = {
    undoLog  = { head = 1, entries = {} },          -- 环形,定长 500
    baseline = { ["cvar:nameplateMaxDistance"] = "60" },
    blame    = { ["cvar:cameraZoomSpeed"] = { by = "Leatrix_Plus", t = 1234567 } },
    autoSwitch = {
      -- 角色轴走 AceDB profileKeys,不在此表
      spec       = { enabled = false, map = { --[[ [specID] = profileName ]] } },
      resolution = { enabled = false, map = { --[[ ["2560x1440"] = profileName ]] } },
      scene      = { enabled = false, map = { --[[ party/raid/arena/pvp/world = profileName ]] } },
      onLeave    = "prompt",   -- prompt | restore | keep
    },
  },
  profiles = {
    ["名字"] = {
      domains  = { cvar = true, binding = false --[[ 该 profile 收录哪些域 ]] },
      cvar     = { --[[ [name] = value ]] },
      binding  = {},  macro = {},  editmode = {},  clickbinding = {},
      mutesound = { --[[ fileID 列表 ]] },  tts = {},
      consoleexec = { --[[ { cmd = "actioncam", args = "full" } ]] },
    },
  },
}
```

profile 内各域的值就是对应适配器 Serialize() 的输出;editmode 域直接存官方 Convert 串,导出给别人也能在原生 EditMode 导入。

### 四轴切换规则(Profiles.lua)

优先级固定:场景 > 专精 > 分辨率 > 角色。判定:从高到低找第一个「已启用且当前上下文有映射」的轴,应用其 profile;都没有则落到 AceDB 角色默认。

- 触发事件:场景 PLAYER_ENTERING_WORLD(instanceType),专精 PLAYER_SPECIALIZATION_CHANGED,分辨率启动时与 DISPLAY_SIZE_CHANGED
- 应用前先把当前活动值快照入撤销日志(source=profile:<name>),保证可回溯
- 上下文退出按 onLeave 处理,默认 prompt(Hyperframe 教训:静默覆盖用户手调值是骂点),可配 restore 或 keep

### 导入导出

Serialize 聚合表加版本头 `{ v = 1, game = "12.1.0" }`,LibSerialize 序列化,LibDeflate 压缩加 EncodeForPrint(WeakAuras 同款管线)。导入:解码后与当前 Serialize 输出 diff,弹清单(项、旧值、新值)确认,逐条经写管线应用(source=import)。

## 6. 事件流水

| 事件 | 动作 |
|---|---|
| ADDON_LOADED(自己) | 初始化 AceDB、注册 slash 与 compartment |
| PLAYER_LOGIN | 枚举(若 AreCVarsLoaded)、官方 Settings 注册、重放第一遍 |
| PLAYER_ENTERING_WORLD | 重放断言、场景轴判定 |
| PLAYER_SPECIALIZATION_CHANGED | 专精轴判定 |
| DISPLAY_SIZE_CHANGED | 分辨率轴判定 |
| CVAR_UPDATE | UI 同步、blame 兜底 |
| PLAYER_REGEN_DISABLED | UI 进战斗锁定态 |
| PLAYER_REGEN_ENABLED | flush CombatQueue,失败照常进清单 |

## 7. UI 架构

自绘,基于暴雪原生模板与 ScrollBox 虚拟化(千条级流畅是 P3 验收项)。单例 MainFrame 持页签容器,页面按第 5 节 SPEC 信息架构分四组。控件不自带逻辑:Widgets 工厂按 control.type 产出,值的读写一律回调 Engine。

搜索(Search.lua):blob 线性扫描(调研第八章:三家独立实现证明零索引结构够用),多词 AND,`tag:` 谓词先筛。

战斗锁定态:PLAYER_REGEN_DISABLED 后 secure 行灰化,tooltip 说明原因,队列内容在日志页可见。

官方集成(Integration/OfficialSettings.lua):RegisterCanvasLayoutCategory 挂跳转按钮;vertical 子集逐项 Settings.RegisterAddOnSetting 加 initializer,AddSearchTags。注册在 PLAYER_LOGIN 一次完成,setting variable 用 `SETTINGSHUB_` 前缀。

## 8. 库依赖决策

| 库 | 用途 | 理由 |
|---|---|---|
| LibStub + CallbackHandler-1.0 | Ace 基座 | AceDB 依赖 |
| AceDB-3.0 | SV 管理、profile、角色轴 | 调研第八章反面教训(Leatrix 手工回写 236 行,漏一行静默丢设置)的正解 |
| LibSerialize | 导入导出序列化 | LibDeflate 只管压缩不管序列化;自写序列化器违背最少代码原则。与 LibDeflate 同作者,WeakAuras 同款组合 |
| LibDeflate | 导出串压缩与 EncodeForPrint | 分享串体积 |

明确不用:

- **AceConfig**:options table 渲染不提供搜索 blob、已修改计数、pending 状态的挂点,搜索型设置中心需要自持数据模型(调研结论)
- **AceGUI**:同上,UI 自绘
- **LibDualSpec**:只覆盖专精一根轴且直接接管 AceDB profile 切换,与四轴切换器冲突
- **LibDBIcon/LibDataBroker**:v1 无小地图钮(SPEC 第 5 节决策)

嵌入方式:Libs/ 目录加 .pkgmeta externals,packager 拉取。

## 9. 自测与合规基建

- `/sh test`:三组断言。枚举计数 ≥1,600;普通与 secure CVar 各一次写、撤销、回默认回环;重放存活标记(写入后置标,重登验证)
- `/sh dump`:全量 CVar(名称/默认值/scope/secure/help)写 SV,P7 管线入口
- 开发期常开:scriptErrors、taintLog=2、taintLogObjectSecrets、addon*RestrictionsForced 六件套
- issecretvalue 守卫:Engine 暴露 `GuardRead(v)`(secret 时返回 nil 并计数),适配器 Read 边界统一过一遍。CVar 层按调研不产 secret(C_CVar 无 SecretReturns),守卫是 G6 要求的防御基线而非猜测性功能

## 10. 决策记录

1. **适配器 8 实现 7 分类**:MuteSound 与 ConsoleExec 共享 ReplayList 基类。提示词包计数口径以此为准。
2. **LibSerialize 进依赖**:P0 只列了 AceDB + LibDeflate,但导出串必须先序列化,自写不如引标准库,偏离已在此声明。
3. **小地图钮不做**:AddonCompartment 满足图形入口,省两个库。
4. **撤销环 + baseline 双层**:环管「最近撤销」,baseline 管「还原与卸载」,解决环淘汰后无法全量还原的问题。
5. **官方 vertical 只挂策展子集**:variable 命名空间永不释放,全量注册会污染官方搜索,也无策展文案可展示。
6. **失败写入保留日志条目并标 failed**:诊断价值大于日志整洁。
7. **四轴优先级 场景 > 专精 > 分辨率 > 角色**:瞬时上下文压过静态上下文;角色轴由 AceDB 兜底。
8. **未策展条目运行时合成 control**:全量浏览器不需要 1,654 份手写定义,枚举即数据(2.2 节)。
