# Sub2API GPT 账号巡检（宿主补丁 v2）

适用于 **Sub2API v0.2.15 + Docker Compose**。把巡检功能和管理页面直接加入主程序，无需安装插件或新增巡检容器。

## 功能

- 只检查常规 OpenAI OAuth 账号，API Key 账号跳过。
- 使用每个账号绑定的有效代理，代理不可用时不退回直连。
- 默认每 30 分钟提问，完整回答符合 iPhone 17 规则则开启调度，不符合则关闭，后续复检正常则恢复。
- 认证、代理、网络错误或不完整响应保留调度状态。
- 原生后台页面：`/admin/gpt-account-monitor`，可管理定时开关、间隔、账号范围、问题、目标代数、立即检查及查看结果。
- 普通业务请求继续使用原有转发路径。

默认问题：

> 不联网，不猜测，直接说出你知道的最新苹果手机。只回答手机型号，不要解释。

iPhone 17 是固定回答规则，不会随日期自动更新，也不等价于通用智力测量。

## 在服务器安装

安装包在 [v2 Release](https://github.com/zhu961212/sub2api-gpt-monitor/releases/tag/v0.2.15-gpt-monitor-ui-v2)，包含 Linux amd64 和 arm64。只适用于正在运行的 **Sub2API 0.2.15**，安装时会短暂重建应用服务。

**如果已安装 v1，请先按 [从 v1 升级](INSTALL.md#从-v1-升级) 回滚并备份旧目录和覆盖文件，然后执行下面的下载与安装。不要直接覆盖正在挂载运行的程序。**

以下命令按原部署目录 `/opt/sub2api`、Compose 文件 `docker-compose.yml`、服务名 `sub2api` 编写：

```sh
(
  set -eu
  cd /opt/sub2api
  curl -fL --retry 3 -o sub2api-0.2.15-gpt-monitor-ui-v2.tar.gz https://github.com/zhu961212/sub2api-gpt-monitor/releases/download/v0.2.15-gpt-monitor-ui-v2/sub2api-0.2.15-gpt-monitor-ui-v2.tar.gz
  printf '%s\n' '82ae15761aaf2f7b641e0e31869440cd181299cf1cfad13d41e3317ad120f1d5  sub2api-0.2.15-gpt-monitor-ui-v2.tar.gz' | sha256sum -c -
  tar -xzf sub2api-0.2.15-gpt-monitor-ui-v2.tar.gz
  sh gpt-monitor-patch/apply.sh docker-compose.yml sub2api
)
```

安装会短暂重建应用服务；保留现有镜像、数据库、Redis 和数据挂载。脚本自动检查版本、文件校验值和镜像架构。请保留解压后的 `gpt-monitor-patch` 目录，它是程序挂载来源。

安装后强制刷新后台，进入 **GPT 账号巡检**，配置并启用，点击 **保存设置 → 立即巡检**。首次默认关闭，已有环境配置除外。

每个待检测账号需要绑定可用代理。完整回答正常则开启调度，不正常则关闭；关闭后仍会复检，恢复正常则重新开启。网络、认证或代理错误保留原来的调度开关。

可以执行下面命令确认安装，输出应包含 `ab80abc-gpt-monitor-ui-v2`：

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml exec -T sub2api /app/sub2api --version
```

若原部署使用多个 Compose 文件、自定义项目名或 `--env-file`，按照 [完整安装说明](INSTALL.md) 保留原有选项操作。

### 查看日志

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml logs --tail=100 sub2api
```

### 回滚

```sh
sh gpt-monitor-patch/rollback.sh docker-compose.yml sub2api
```

回滚恢复原 Compose 程序，不删除数据卷；已经调整过的账号调度开关不会自动还原。只读程序挂载期间不支持后台直接覆盖程序自更新。

## 源码和验证

- 上游：[Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api)
- 基线提交：`ab80abc6d1f929a6864c8804fd077b509d21fda2`
- [源码补丁](sub2api-builtin-gpt-monitor.patch)
- Release 附有完整修改后源码 ZIP 与 SHA-256 文件。
- 包含原项目 LICENSE，修改后的对应源码随安装包一同公开提供。

v2 将账号扫描改为每页 200 个的轻量查询，状态查询只加载展示字段；保存巡检结果不再触发调度缓存重建，调度开关与 outbox 通知在同一事务提交。同时复用回答匹配正则，减少流式响应处理的内存分配。

已通过后端巡检回归测试、10 项前端测试和 9 项模拟 Docker 安装测试，源码补丁通过基线应用检查。Linux 程序为交叉编译产物，未在用户实际服务器或真实 GPT 账号上执行验证。具体范围见 [VALIDATION.txt](VALIDATION.txt)。
