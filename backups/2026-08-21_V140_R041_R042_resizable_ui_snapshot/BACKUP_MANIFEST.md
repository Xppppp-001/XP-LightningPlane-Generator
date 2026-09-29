# XP闪电面片生成器：V1.4.0／R-041／R-042 当前快照

- 备份日期：2026-08-21
- 插件版本：V1.4.0
- 备份基线：R-041 用户控制横向分段；R-042 可缩放紧凑界面与按需滚动
- 快照性质：静态实现、测试扩展与打包快照；不是已经完成 Max 2023 实机回归的稳定版

## 备份内容

- `XP闪电面片生成器_R041_R042_完整源码.zip`
  - SHA256：`4FC8634DBBFEAF01FD68D9CC8AC9360451C350A5971F623408FD5312E44C7485`
  - 包含：`src`、`package`、`tools`、`tests`、`artifacts`、README、需求、中文使用说明、项目规则和 `.gitignore`。
- `XP闪电面片生成器_V1.4.0_R041_R042_当前快照.mzp`
  - SHA256：`D5C72FB181FDE31885EC86A4DD28C10EC017EEA027EEE62D36C6D5E709CA1804`
  - 与备份时 `dist/XP闪电面片生成器_V1.4.0.mzp` 字节完全一致。
- `REQUIREMENTS_R041_R042.md`
  - SHA256：`AB7E920F00E3955F81E256C13712D22D3A3B571D1BB80B1B0790E10C75F0354C`
- `插件使用说明_R041_R042.md`
  - SHA256：`37240B0B2F21428836D24F2B6A944B46089524A7059049A3AFD317373136A0D9`

## 当前功能基线

- R-041：纵向 `L = 平面面数 + 额外加面`，横向分段 `M = 1～8`，每支严格生成 `L×M` 个四边面和 `(L+1)×(M+1)` 个几何／贴图顶点。
- R-042：固定 `createDialog` 已替换为原生 `newRolloutFloater`；默认窗口 `410×760`，宽高均可调整，完整内容不足时使用 `scrollBar:#asNeeded`。
- 界面修改未改变既有 FFD、噪波、途经点、Twist、宽度、收尖、UV、命名、轴心或实时原位更新算法。

## 已完成验证

- `tools/build-package.ps1` 已重新构建当前 MZP。
- `tools/verify-package.ps1` 通过：主脚本为 UTF-8 BOM、内部函数前向引用 `0`、包内源码与 `src` 一致。
- MZP 只包含 `mzp.run` 与 `XP_LightningGenerator.ms` 两个预期文件。
- 旧 `createDialog XP_LG_Rollout` 已移除；新 Floater、按需滚动、关闭清理和 UI 自动测试断言均已写入当前源码／测试。
- `git diff --check` 通过。
- 完整源码 ZIP 未包含 `.git`、`build`、旧 `backups`、`_lark_auth_qr.png` 或 `_update_lark.py`。

## GitHub 记录

- 私有仓库：`https://github.com/Xppppp-001/XP-LightningPlane-Generator`
- 上传分支：`agent/v140-r040-backup`
- 现有草稿 PR：`https://github.com/Xppppp-001/XP-LightningPlane-Generator/pull/1`
- 本目录随本轮备份提交推送；精确提交号以该分支最新 Git 历史为准。

## 仍待验证／已知范围

- R-040～R-042 尚未在隔离的单实例 Autodesk 3ds Max 2023 中执行当前完整核心与中文 UI 回归。
- R-041 仍需在用户原贴图场景比较不同横向分段的视觉结果。
- R-042 仍需实机确认真实窗口拖拽缩放、滚动条按需显示／隐藏、重复载入和底部控件操作。
- 本轮没有启动第二个 Max 实例，以避免已知的并发 OpenCL 初始化错误、卡顿或影响用户当前场景。

## 回退方法

需要恢复此状态时，将完整源码 ZIP 解压到新的空目录；只需要运行插件时，可直接使用本目录中的 R-041／R-042 MZP。恢复后仍应在单实例 3ds Max 2023 中完成待验项目，不要把本快照描述为已完成实机验收的稳定版本。
