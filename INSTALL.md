# Sub2API 0.2.16 巡检修复版 v2

此更新包用于已安装 `0184257-gpt-monitor` 的 Sub2API 0.2.16。新构建标记为 `0184257-gpt-monitor-v2`，应用版本仍为 0.2.16。包含 Linux amd64、arm64 程序。

巡检的目标保持简单：使用账号绑定的代理、固定 `gpt-6-astra / XHigh` 检测；完整回答符合规则时开启调度，不符合时关闭调度；请求失败时保留原调度。调度写入只修改账号的 `schedulable` 开关。OAuth 必要的令牌刷新沿用宿主机制。

本次修复：

- 复用官方 OpenAI 连接池及 HTTP/2 代理兼容策略，取消巡检独有的 90 秒响应头硬上限，使用配置的检测期限。
- 区分未绑定代理、代理认证、账号认证、限流、额度、模型不可用、连接超时和响应中断，记录安全错误代码、HTTP 状态及耗时。
- 正常令牌刷新、使用统计和代理记录更新时间不再导致误报；仍使用账号本身的代理，不切换到直连。
- 使用最新已保存的有效令牌处理旧缓存；正常令牌轮换不再被当作失败。
- 调度数据库写入失败单独提示，不再与账号变更混为一谈。错误信息不输出令牌、代理密码或上游原始正文。

## 更新现有巡检版

以下命令适用于容器及服务名均为 `sub2api`、原配置文件为 `docker-compose.yml` 的现有巡检版。它自动定位原部署目录，从固定 GitHub Release 下载并校验更新包：

```sh
(
  set -eu
  deploy_dir=$(docker inspect sub2api --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}')
  [ -n "$deploy_dir" ] && [ "$deploy_dir" != '<no value>' ]
  cd "$deploy_dir"
  test -f docker-compose.yml
  test -f docker-compose.gpt-monitor.yml
  test -f docker-compose.gpt-monitor.rollback-0.2.16.yml
  test ! -e gpt-monitor-patch-0.2.16-v2
  test ! -L gpt-monitor-patch-0.2.16-v2
  test ! -e docker-compose.gpt-monitor-v2.yml
  test ! -L docker-compose.gpt-monitor-v2.yml
  curl -fL --retry 3 -o sub2api-0.2.16-gpt-monitor-v2.tar.gz https://github.com/zhu961212/sub2api-gpt-monitor/releases/download/v0.2.16-gpt-monitor-v2/sub2api-0.2.16-gpt-monitor-v2.tar.gz
  printf '%s\n' 'ce75eb530500dd66e50eac39c6314876f4499276c8f387234769fb14fb49ab6a  sub2api-0.2.16-gpt-monitor-v2.tar.gz' | sha256sum -c -
  tar -xzf sub2api-0.2.16-gpt-monitor-v2.tar.gz
  sh gpt-monitor-patch-0.2.16-v2/update.sh docker-compose.yml sub2api
)
```

如果之前已解压 v2 目录或生成 v2 覆盖文件，命令会停止，请先检查现有文件，不要覆盖正在挂载的程序。

按实际配置替换 Compose 文件名和服务名。更新脚本会短暂重建应用服务并等待健康，生成 `docker-compose.gpt-monitor-v2.yml`。它保留旧程序、旧巡检覆盖文件及官方 0.2.16 回滚记录。新旧程序放在不同目录；不要覆盖旧目录内正在挂载的二进制。

更新后：

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor-v2.yml exec -T sub2api /app/sub2api --version
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor-v2.yml logs --tail=200 sub2api
```

版本输出应包含 `0184257-gpt-monitor-v2`。刷新巡检页面，点击“立即巡检”；旧结果不会凭空变成新诊断，需等待本轮结果。没有代理的账号先在账号管理中绑定有效代理。后续应用启动使用原 Compose 文件和新的 v2 覆盖文件。

## 恢复旧巡检程序

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml up -d --no-deps --force-recreate --pull never --no-build --wait --wait-timeout 180 sub2api
```

如需卸载巡检并恢复官方 0.2.16，使用：

```sh
sh gpt-monitor-patch-0.2.16-v2/rollback.sh docker-compose.yml sub2api
```

恢复程序不会反向修改已经保存的调度开关。

## 源码核对与验证范围

用户提供的 `sub2api-0.2.16.zip` 内全部 4322 个文件，与官方基线提交 `01842576b3d5c1e2545b5a99ad555d36e28ed306` 一致；源码压缩包自身不含巡检扩展。本次修改基于该基线上的现有巡检补丁，没有数据库 schema 或迁移变更。

后端巡检、账号调度、错误分类与连接路径进行了定向回归；前端 12 项页面/i18n 测试、TypeScript 检查和生产构建通过。更新脚本使用模拟 Docker 验证；Windows 下两项权限相关测试跳过。详见包内 `VALIDATION.txt`。

用户提供的旧日志只有通用错误，无法恢复每个账号当时的真实上游原因。本次未连接服务器、真实账号或代理，实际网络是否恢复仍需更新后的巡检结果确认。
