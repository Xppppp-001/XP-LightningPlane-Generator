# XP闪电面片生成器：R-031 恒宽稳定版备份

- 备份日期：2026-08-13
- 插件版本：V1.2.0
- 备份基线：R-031 多途经点恒宽与自动安全补面
- 用户确认：当前表现“还不错”，可作为新的稳定回退点

## 备份内容

- `XP闪电面片生成器_R031_完整源码.zip`
  - SHA256：`D672248B519C472F5A9A5374BD29CC0E97AE254B2E7B0702140F792791CBA939`
  - 包含：`src`、`package`、`tools`、`tests`、`artifacts`、README、需求、使用说明和项目规则。
- `XP闪电面片生成器_V1.2.0_R031_稳定版.mzp`
  - SHA256：`84639576B17F2C56BD616A4AB0A225C838B807CF9826E1E9D26FFF2E5D485F54`
  - 与备份时 `dist/XP闪电面片生成器_V1.2.0.mzp` 字节完全一致。
- `REQUIREMENTS_R031.md`
  - SHA256：`3428B830162668B7C8DA7748AEA7AE9B813AB73E0301BF7701556521E1564BFA`
- `插件使用说明_R031.md`
  - SHA256：`DDD6208F8FCFCA39D4AA46F735EF7CB56CC70687D36FB9A56610566D433E02FA`

## 已知验证状态

- 用户指定的 Autodesk 3ds Max 2023 核心回归：`artifacts/gui-smoke-result.txt = PASS`。
- 最终 MZP 中文 UI 回归：`artifacts/ui-smoke-r031-final.txt = PASS`，43 个控件通过。
- 包结构、UTF-8 BOM、内部函数前向引用和包内源码一致性验证通过。
- 用户已对复杂多途经点场景进行视觉复验，并确认当前表现可接受。

## 仍待验证／范围外

- 尚未用 Windows 资源管理器物理拖放完成最终人工安装动作。
- 尚未执行本版本的 FBX 静态导出复验。
- 同一分支远距离非相邻区段之间及不同分支之间的全局空间自相交消除不在当前版本范围。
