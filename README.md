# Sub2API 0.2.16 · GPT 账号巡检补丁

基于官方 `v0.2.16` 的实际发布提交 `01842576b3d5c1e2545b5a99ad555d36e28ed306`。程序版本显示 **0.2.16**，构建标记为 `0184257-gpt-monitor`。这是宿主源码补丁及其预编译程序，不是独立官方版本。

| 检测模型 | 推理强度 |
| --- | --- |
| **gpt-6-astra** | **XHigh** |

实际请求固定发送 `model: "gpt-6-astra"` 和 `reasoning: {"effort":"xhigh"}`，不受账号模型映射影响，不自动回退到其他模型。旧配置自动采用固定参数，巡检间隔、账号范围等其他设置保留。页面固定展示模型与推理强度。

## 调度规则

- 只检查符合条件的 OpenAI OAuth 账号，每个账号使用自己绑定的有效代理。
- 完整回答符合已保存的 iPhone 代数规则：开启调度。
- 完整回答不符合：关闭调度；后续继续检查，恢复正常后重新开启。
- 模型不可用、认证、代理、网络、超时或不完整响应：保持原调度状态，不换模型重试。
- 默认每 30 分钟巡检；按每页 200 个账号轻量读取。观察结果保存不触发调度缓存重建，调度变更与通知同一事务提交。

默认问题：

> 不联网，不猜测，直接说出你知道的最新苹果手机。只回答手机型号，不要解释。

iPhone 17 是默认固定回答规则，不会随日期自动更新，也不等价于通用智力测量。

## 下载和安装

[0.2.16 发布页](https://github.com/zhu961212/sub2api-gpt-monitor/releases/tag/v0.2.16-gpt-monitor) 提供 Linux amd64/arm64 安装包、完整源码、源码补丁及 SHA-256 校验文件。

**当前仍运行 0.2.15 + 巡检 v3：先按 [升级说明](INSTALL.md#从官方-0215--巡检-v3-升级) 备份数据库、解除旧程序挂载并升级官方 0.2.16，然后安装本补丁。不要把新文件覆盖到运行中的旧补丁目录。**

以下仅用于已经运行原版 `0.2.16 / 01842576…` 的部署。按实际路径、Compose 文件和服务名修改：

```sh
(
  set -eu
  cd /opt/sub2api
  curl -fL --retry 3 -o sub2api-0.2.16-gpt-monitor.tar.gz https://github.com/zhu961212/sub2api-gpt-monitor/releases/download/v0.2.16-gpt-monitor/sub2api-0.2.16-gpt-monitor.tar.gz
  printf '%s\n' 'd4dbf47dcd28386fc12b0e723512e813800785b5083ba7aa206d2edb399173c4  sub2api-0.2.16-gpt-monitor.tar.gz' | sha256sum -c -
  tar -xzf sub2api-0.2.16-gpt-monitor.tar.gz
  sh gpt-monitor-patch-0.2.16/apply.sh docker-compose.yml sub2api
)
```

安装会短暂重建应用容器。强制刷新后台，进入 **GPT 账号巡检**，确认显示 `gpt-6-astra / XHigh`，保存并启用，然后点击“立即巡检”。保留解压目录和生成的 Compose 覆盖文件。

[完整安装、升级、回滚说明](INSTALL.md) 包含原文件仍使用 0.2.15 镜像时的操作方式。新回滚脚本使用专用镜像记录恢复官方 **0.2.16**，不会按旧标签降回 0.2.15。补丁不新增数据库迁移；官方 0.2.16 自带的迁移会正常执行。

## 后续官方更新

源码补丁需要针对新的官方发布重新应用、验证和编译。保留当前程序挂载时，仅拉取官方新镜像不会更新实际运行的程序；不要把本安装包直接用于其他官方版本或提交。

0.2.15 用户的历史包仍在 [v3 Release](https://github.com/zhu961212/sub2api-gpt-monitor/releases/tag/v0.2.15-gpt-monitor-ui-v3)。此前 v1/v2 基线差异说明保留在对应历史 Release 中。

## 源码与验证

- [源码补丁](sub2api-builtin-gpt-monitor.patch)
- [上游基线](UPSTREAM_BASE.txt)
- [验证记录](VALIDATION.txt)
- [下载校验值](SHA256SUMS.txt)

已通过后端配置、请求和调度回归测试，12 项前端 UI/i18n 测试、TypeScript 检查、生产构建和 21 项模拟 Docker 测试。未连接真实 GPT 账号或部署到用户服务器，OAuth 账号的实际模型访问权限仍需安装后检查。
