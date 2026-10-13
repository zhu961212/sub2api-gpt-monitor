# Sub2API GPT 账号巡检（内置管理页补丁）

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

安装包在 [Releases](https://github.com/zhu961212/sub2api-gpt-monitor/releases/tag/v0.2.15-gpt-monitor-ui)，包含 Linux amd64 和 arm64。

以下命令按原部署目录 `/opt/sub2api`、Compose 文件 `docker-compose.yml`、服务名 `sub2api` 编写：

```sh
cd /opt/sub2api
curl -fL --retry 3 -o sub2api-0.2.15-gpt-monitor-ui.tar.gz https://github.com/zhu961212/sub2api-gpt-monitor/releases/download/v0.2.15-gpt-monitor-ui/sub2api-0.2.15-gpt-monitor-ui.tar.gz
printf '%s\n' '9eeac2185f7a2a08157c9e98760e503f8c37bf1f03547623e080c663327a6004  sub2api-0.2.15-gpt-monitor-ui.tar.gz' | sha256sum -c -
tar -xzf sub2api-0.2.15-gpt-monitor-ui.tar.gz
sh gpt-monitor-patch/apply.sh docker-compose.yml sub2api
```

安装会短暂重建应用服务；保留现有镜像、数据库、Redis 和数据挂载。脚本自动检查版本、文件校验值和镜像架构。请保留解压后的 `gpt-monitor-patch` 目录，它是程序挂载来源。

安装后强制刷新后台，进入 **GPT 账号巡检**，配置并启用，点击 **保存设置 → 立即巡检**。首次默认关闭，已有环境配置除外。

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

已通过后台配置、动态启停、OAuth 筛选、代理隔离、完整 SSE、调度 CAS、Redis 协调、前端交互及构建测试；安装脚本通过 7 项模拟 Docker 测试。Linux 程序为交叉编译产物，未在用户实际服务器或真实 GPT 账号上执行验证。
