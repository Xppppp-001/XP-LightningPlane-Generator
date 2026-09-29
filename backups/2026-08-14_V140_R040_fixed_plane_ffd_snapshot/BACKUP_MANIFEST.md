# XP闪电面片生成器：V1.4.0／R-040 当前快照

- 备份日期：2026-08-14
- 插件版本：V1.4.0
- 备份基线：R-040 用户控制加面与固定 Plane／FFD 变形
- 快照性质：静态实现与打包快照；不是已经完成 Max 2023 实机回归的稳定版

## 备份内容

- `XP闪电面片生成器_R040_完整源码.zip`
  - SHA256：`D0EC75B89053429C2549DE0C9D8998FF2BFCCE86D1D7396CB8B956333706DDD7`
  - 包含：`src`、`package`、`tools`、`tests`、`artifacts`、README、需求、中文使用说明、项目规则和 `.gitignore`。
- `XP闪电面片生成器_V1.4.0_R040_当前快照.mzp`
  - SHA256：`BC0649D7C237F843C7F5821B93B53405613982153B28F20C25A4BA03726DE9B2`
  - 与备份时 `dist/XP闪电面片生成器_V1.4.0.mzp` 字节完全一致。
- `REQUIREMENTS_R040.md`
  - SHA256：`FBA24E134560370CECB0CFC2090B8B3B815994439EE61C0A18287FBBBE317436`
- `插件使用说明_R040.md`
  - SHA256：`2142E9B2FB3FF5BC2F761300827C043B409AE5A6B250CE342A1B91546EAA7AF1`

## 已完成验证

- `tools/verify-package.ps1` 通过：主脚本 UTF-8 BOM、内部函数前向引用 `0`、包内源码与 `src` 一致。
- MZP 只包含 `mzp.run` 与 `XP_LightningGenerator.ms` 两个预期文件。
- R-021 的干净会话拾取根因仍保持修复：被依赖函数先于 `XP_LG_PickFilter` 定义，拾取按钮在过滤器定义之后引用。
- 发布包未引用开发机绝对路径、外部 Python 包、第三方渲染器或 OpenCL。

## GitHub 记录

- 私有仓库：`https://github.com/Xppppp-001/XP-LightningPlane-Generator`
- 发布分支：`agent/v140-r040-backup`
- 首次快照提交：`80f0c3d`
- 草稿 PR：`https://github.com/Xppppp-001/XP-LightningPlane-Generator/pull/1`
- PR 尚未合并到 `main`。

## 仍待验证／已知范围

- R-040 固定 Plane／FFD 主链尚未在隔离的单实例 Autodesk 3ds Max 2023 中执行完整核心和中文 UI 回归。
- 尚需用用户原贴图场景确认视觉结果，并人工验证 Windows 资源管理器拖放安装。
- 本轮没有启动第二个 Max 实例，避免再次触发并发 OpenCL 初始化错误或影响用户当前场景。

## 回退方法

需要恢复此状态时，解压完整源码 ZIP 覆盖到新的空目录；最终交付包直接使用本目录中的 R-040 MZP。不要把本快照描述为已经完成 R-040 实机验收的稳定版本。
