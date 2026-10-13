# Sub2API 0.2.16 · GPT 账号巡检修复版 v2

基于官方 0.2.16（`01842576b3d5c1e2545b5a99ad555d36e28ed306`），新构建标记为 `0184257-gpt-monitor-v2`。此次更新用于已安装 `0184257-gpt-monitor` 的部署。

每个账号使用自己绑定的代理，固定 **gpt-6-astra / XHigh** 检测：完整回答符合已保存规则时开启调度，不符合时关闭；连接、认证、模型或响应失败保持原调度。后续复检符合规则可自动恢复。

## 本次修复

- 巡检复用官方 OpenAI 连接池及 HTTP/2 代理兼容策略，检测超时按配置生效。
- 页面和日志显示具体安全错误分类、HTTP 状态及耗时，避免所有错误都显示通用“网络、认证、代理”提示。
- 正常令牌刷新、使用记录更新或代理改名不再阻止调度切换；使用最新已保存的有效令牌处理旧缓存。
- 调度写入只更新 `schedulable` 开关；数据库写入失败单独提示。
- 修正安装包控制文件换行，校验清单和基线记录在 Linux 上使用 LF。

## 下载与更新

[v2 发布页](https://github.com/zhu961212/sub2api-gpt-monitor/releases/tag/v0.2.16-gpt-monitor-v2) 提供 Linux amd64/arm64 程序、完整源码、源码补丁、安装说明和校验值。

当前运行 **0.2.16 旧巡检版**：按照 [更新说明](INSTALL.md) 下载并执行 `update.sh`。更新包使用独立目录 `gpt-monitor-patch-0.2.16-v2`，生成独立的 `docker-compose.gpt-monitor-v2.yml`，保留旧程序和官方回滚记录。更新会短暂重建应用服务。

当前运行**官方原版 0.2.16**，或仍在 **0.2.15**：先按照 [原版安装/升级说明](https://github.com/zhu961212/sub2api-gpt-monitor/blob/v0.2.16-gpt-monitor/INSTALL.md) 安装匹配的 0.2.16 巡检版，再使用本次更新包。本次 updater 会检查旧构建标记，不能直接用于任意版本。

安装成功后版本应包含 `0184257-gpt-monitor-v2`。刷新后台并重新运行巡检，新诊断会随新一轮结果显示。

## 源码与验证

- [源码补丁](sub2api-builtin-gpt-monitor.patch)
- [上游基线](UPSTREAM_BASE.txt)
- [验证记录](VALIDATION.txt)
- [Release 附件校验值](SHA256SUMS.txt)

用户提供的官方源码共 4322 个文件，全部与上述基线一致；本次没有新增数据库 schema 或迁移。后端定向回归、前端 12 项页面/i18n 测试、TypeScript 检查、生产构建和 Linux 两架构交叉编译通过。更新器 18 项模拟 Docker 测试通过，2 项 Windows 权限相关测试跳过。包内清单、基线记录和 Linux shell 校验另行核验。

未连接真实 GPT 账号或部署到服务器，实际网络和账号模型权限需安装后复检。默认回答规则为 iPhone 17，可在后台修改；它不是通用智力测量。

历史发布与原版回滚说明均保留。
