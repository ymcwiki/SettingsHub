# 实机验证台账

约定:动到相关模块前先查这里。状态只有三种:UNVERIFIED(未验证,按保守假设实现)、
CONFIRMED(实机确认,写明客户端版本与日期)、REFUTED(推翻,写明实测行为与代码改动)。

## 1. C_ClickBindings.SetProfileByInfo 的 HasRestrictions 语义

状态:UNVERIFIED。保守假设:战斗中禁写,Adapters/ClickBinding.lua 一律 IsCombatSafe=false,
InCombatLockdown 时拒绝并入队。
验证方法:脱战调用 SetProfileByInfo 确认生效;开 addonCombatRestrictionsForced 1 再调用,
观察是否报错/静默失败/要求硬件事件;记录 C_ClickBindings.CanUseBindings 类谓词的返回。

## 2. test_camera* 是否随 config 服务器同步、被重置的时机

状态:UNVERIFIED。当前实现按期望态登录重放兜底(无论它掉不掉,重放都会补回)。
验证方法:改 test_cameraOverShoulder 后重登看值;换机器登同账号看值;
跑一次 C_CVar.ResetTestCVars 与版本更新后各查一次。

## 3. census 默认值与描述对照实机

状态:UNVERIFIED(批量)。census 里 A/D/G 主题多处 help 错位,文案已按领域知识改写;
默认值以运行时 GetCVarInfo 为准(L0 权威),种子仅展示用。
验证方法:游戏内跑 /sh dump,用 scripts/dump_diff.py 对照 Data/ 与 census JSON,差异回写。
2026-07-17 增补:12.0.7 实机上 miniWorldMap / showDungeonEntrancesOnMap / showDelveEntrancesOnMap
的 scope 为 character,12.1.0 census 记为 account;先按版本差异对待,12.1 上线后 dump 复核。

## 4. 战斗保护 CVar 集合(替代 AIO 手工 65 条表)

状态:程序化方案已实现(GetCVarInfo 第 6 位 isSecure,枚举时逐条采集),无需人工清单。
验证方法:/sh dump 后统计 secure 位条数,与 census 的 54 条对比,差异说明版本变化。

## 5. commandType==Command 的全量命令表

状态:UNVERIFIED(本地归档缺失)。
验证方法:游戏内跑一次 /sh dump 的姊妹命令(后续加 /sh dumpcmd),筛可设置化条目。

## 6. addon*RestrictionsForced 六件套除 Chat 外是否跨重启持久

状态:UNVERIFIED(官方文档未声明)。
验证方法:六个各设 1,重启客户端后逐个 GetCVar 检查。

## 7. 钓鱼预设数值组合(fishing_preset)

状态:UNVERIFIED。SoftTargetInteractArc=2 / SoftTargetInteractRange=15 /
SoftTargetNameplateInteract=1,对标 Advanced Soft Target 常用值。UI 已隐藏(verify 标记)。
验证方法:实机钓鱼,确认浮漂偏离准星也能互动收竿,微调数值后解除 verify。

## 8. D/F/G 主题 verify 标记项

状态:UNVERIFIED。WorldTextRampDuration_v2 / WorldTextGravity_v2 的单位与手感、
DynamicRenderScaleMin 步进、Sound_DSPBufferSize 合法值、Sound_OutputSampleRate 是否需
重启,均待实机确认后在 Data/ 里解除 verify 标记。

## 9. 聊天窗口域 Set* 写入后的 UI 即时刷新程度(v0.3)

状态:UNVERIFIED。SetChatWindow*/Add*/Remove* 写的是 chat-cache;已打开的 FloatingChatFrame
不经 FCF 函数刷新可能不立即反映(本插件零 taint 约束下不调 FCF_*)。当前实现:恢复后打印
/reload 建议。
验证方法:实机恢复一份聊天窗口快照,观察名字/字号/颜色/消息组即时变化程度;/reload 后再对照;
若即时生效良好则移除提示,若完全不生效则把 chatwindow 域标注 requiresReload。

## 10. Chat*Volume 三件套的压低(ducking)语义(v0.3)

状态:UNVERIFIED。ChatAmbienceVolume / ChatMusicVolume / ChatSoundVolume 按「语音聊天激活时
对应通道压低到的音量倍率」撰写文案,数据里已标 verify(主题页隐藏)。
验证方法:进语音频道说话,分别改三值观察环境音/音乐/音效音量变化;确认后解除 verify。

## 11. GamePad 数值项的取值范围(v0.3)

状态:UNVERIFIED(范围为保守估计)。GamePadCameraYaw/PitchSpeed 用了 -4..4(负值反转),
GamePadVibrationStrength 用了 0..1,GamePadFaceMovementMaxAngleCombat 0..180。
验证方法:接手柄实测边界值;越界值观察引擎是否钳制;按实测修 Data/Curated_J_Input.lua 的 range。
