# XP模型扩宽工具 V1.2.0／R-043～R-046 回退快照

- 备份日期：2026-09-18
- 基线：完整截面双侧扩宽、中线固定、显式端部起点与按世界中线累计弧长进行首尾倍率渐变。
- 验证性质：扩宽工具已通过 Max 2023.2.2 隔离实例 7759 项断言；本快照不表示用户原模型／原贴图或所有异常分支已验收。
- 测试入口固定：`C:\Program Files\Autodesk\3ds Max 2023\3dsmax.exe`。

## 内容与校验

- `XP模型扩宽工具_V1.2.0_完整项目源码.zip`：45 个文件，包含 src、package、tools、tests、已保留验证证据、docs、dist、README、需求、两份中文说明、项目规则与 .gitignore；保留原闪电生成器项目以便独立恢复构建。
- `XP模型扩宽工具_V1.2.0.mzp`：与 dist 当前扩宽包逐字节一致。
- 独立的 `REQUIREMENTS.md`、`模型扩宽工具使用说明.md`、`插件使用说明.md`。
- `SOURCE_SHA256SUMS.txt`：源码 ZIP 内每个文件的原始字节 SHA256。
- `SHA256SUMS.txt`：本目录文件校验清单（清单自身除外）。
- `BACKUP_VERIFICATION.txt`：ZIP 全部条目逐字节比对和独立副本校验结果。

快照不包含 .git、build、历史 backups、无关认证二维码／临时脚本、进程 PID 和失败 Batch 启动日志。备份保存的是上传前的工作区字节；上传确认记录随后写回项目需求，不改写本回退基线。

## 证据与待验范围

- `artifacts/ribbon-gui-status.txt`：两个测试套件 PASS，实际运行版本 Max 2023.2.2。
- 统一扩宽 3598 项、渐变／UV／UI 4161 项断言，合计 7759 项 PASS。
- 启用通道 -2/-1/0/1/3/7 的支持、数量、每个 UVW、每个贴图面角索引在应用／拒绝／无操作／撤销／重做中精确保持；包含接缝、未引用及 0～1 外坐标，Preserve UVs 开／关均通过。
- 中文起点设置、交换首尾、应用按钮事件、MZP 重复加载和一次撤销通过。
- 原闪电生成器源码／V1.4.0 包保持原基线；本轮仅静态校验生成器，未重新执行其核心实机回归。
- 用户原模型／贴图视觉、Windows 物理拖放、分叉／闭环／非流形专项夹具和异常写入恢复故障注入仍待实机验证。
- R-045 紧弯重叠未修复；不新增限幅或自动局部收窄。

## GitHub 与恢复

- 现有私有仓库：https://github.com/Xppppp-001/XP-LightningPlane-Generator
- 沿用上传分支：`agent/v140-r040-backup`；现有草稿 PR：https://github.com/Xppppp-001/XP-LightningPlane-Generator/pull/1
- 本目录随当前备份提交上传；提交号及远端确认以项目 REQUIREMENTS.md 后续记录和分支 Git 历史为准。
- 只运行工具：将本目录 MZP 拖入 Max 2023。恢复开发基线：先核对 SHA256，再把完整源码 ZIP 解压到新的空目录。备份不包括用户场景，恢复不应覆盖制作场景。
