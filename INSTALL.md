# Sub2API 0.2.16：GPT 账号巡检宿主补丁

安装包：`sub2api-0.2.16-gpt-monitor.tar.gz`，解压目录：`gpt-monitor-patch-0.2.16`。基于官方 Sub2API `v0.2.16`、完整提交 `01842576b3d5c1e2545b5a99ad555d36e28ed306`，程序版本保持 `0.2.16`，构建标记为 `0184257-gpt-monitor`，包含 Linux amd64、arm64 程序。

检测模型固定为 **`gpt-6-astra`**，推理强度固定为 **XHigh**（请求值 `xhigh`）。旧配置中的其他模型会统一归一到这一固定值；页面不再允许修改模型。检测回答符合目标 iPhone 型号规则时开启账号调度，不符合时关闭，后续复检恢复正常则重新开启。代理、网络、认证等请求失败不改变原调度状态。

这是应用源码补丁后编译的程序挂载包，直接替换现有应用容器中的程序。无需插件、公钥、管理员 API Key 或新增容器。补丁不新增数据库迁移；升级官方 `0.2.16` 时，该版本自带的迁移会正常执行。已有巡检配置、检查结果和账号保存在原数据库中。

本包只支持上述精确官方构建。同版本号但不同 commit、旧版宿主补丁和已安装本补丁的程序都会被安装脚本拒绝。后续官方升级仍需匹配新版源码重新编译补丁；保留旧程序挂载时，仅更新镜像不会更新实际运行的程序。

## 已运行官方 0.2.16：安装补丁

在原 Compose 部署目录操作，保持原 Compose 文件、`.env` 和项目名称不变。以下默认应用服务名为 `sub2api`，可按实际名称替换。安装会短暂重建应用容器。

```sh
tar -xzf sub2api-0.2.16-gpt-monitor.tar.gz
sh gpt-monitor-patch-0.2.16/apply.sh docker-compose.yml sub2api
```

脚本校验安装包，读取当前运行程序的版本及完整 commit，并按当前容器镜像架构选择程序。然后生成两个文件：

- `docker-compose.gpt-monitor.yml`：固定当前官方镜像 ID，并只读挂载新巡检程序。
- `docker-compose.gpt-monitor.rollback-0.2.16.yml`：仅固定同一个官方 `0.2.16` 镜像 ID，用于卸载补丁后恢复官方程序。

任一文件已存在时安装都会停止，不覆盖旧文件。保留这两个文件及 `gpt-monitor-patch-0.2.16` 目录。升级官方版时使用的 `docker-compose.official-0.2.16.yml` 也可以保留；安装脚本不修改它。

安装后检查：

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml exec -T sub2api /app/sub2api --version
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml logs --tail=100 sub2api
```

应看到 `Sub2API 0.2.16 (commit: 0184257-gpt-monitor,`。浏览器强制刷新后台，进入 **GPT 账号巡检** 或 `/admin/gpt-account-monitor`，确认固定模型显示为 `gpt-6-astra / XHigh`，保存并启用，再点击“立即巡检”。

## 从官方 0.2.15 + 巡检 v3 升级

先备份数据库并升级官方程序，再装新补丁。新包使用独立目录，不能解压覆盖仍被挂载的旧 `gpt-monitor-patch` 目录。以下适用于原部署只有 `docker-compose.yml`、应用服务 `sub2api`、PostgreSQL 容器 `sub2api-postgres` 的情况。其他名称请对应替换；多个 Compose 文件或自定义项目名请参考后文。

1. 进入原部署目录并备份数据库。命令从 PostgreSQL 容器读取数据库用户名和数据库名，不显示密码。备份成功且目录可由 `pg_restore` 读取后，才继续升级。

   ```sh
   cd /opt/sub2api
   (
     set -eu
     umask 077
     backup="sub2api-before-0.2.16-$(date +%Y%m%d-%H%M%S).dump"
     test ! -e "$backup"
     docker exec sub2api-postgres sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "${POSTGRES_DB:-$POSTGRES_USER}" -Fc' > "$backup"
     test -s "$backup"
     docker exec -i sub2api-postgres pg_restore -l < "$backup" > /dev/null
     printf '数据库备份：%s\n' "$backup"
   )
   ```

2. 备份旧巡检覆盖文件，保留旧程序目录；创建官方 `0.2.16` 镜像覆盖文件。以下命令拒绝覆盖已有同名文件。

   ```sh
   (
     set -eu
     test -f docker-compose.gpt-monitor.yml
     test ! -e docker-compose.gpt-monitor.pre-0.2.16.yml.bak
     test ! -e docker-compose.official-0.2.16.yml
     (
       umask 077
       set -C
       cat > docker-compose.official-0.2.16.yml <<'EOF'
   services:
     sub2api:
       image: weishaw/sub2api:0.2.16
   EOF
     )
     docker compose -f docker-compose.yml -f docker-compose.official-0.2.16.yml config --quiet
     docker compose -f docker-compose.yml -f docker-compose.official-0.2.16.yml pull sub2api
     mv docker-compose.gpt-monitor.yml docker-compose.gpt-monitor.pre-0.2.16.yml.bak
     docker compose -f docker-compose.yml -f docker-compose.official-0.2.16.yml up -d --no-deps --force-recreate --no-build --wait --wait-timeout 180 sub2api
   )
   ```

   这次重建只加载原配置和官方镜像覆盖文件，解除旧巡检程序挂载，并等待官方 `0.2.16` 启动健康后再继续。官方自带的数据库迁移会正常执行，数据库、Redis 容器及数据卷保留。这里的 `--wait` 需要支持该选项的 Docker Compose；当前服务器的 `v5.5.0` 可使用。

3. 确认官方程序正常启动，版本为 `0.2.16`，commit 必须完整匹配 `01842576b3d5c1e2545b5a99ad555d36e28ed306`。若容器仍在启动，请检查日志并等待；若 commit 不同，请停止，不要跳过检查。

   ```sh
   docker compose -f docker-compose.yml -f docker-compose.official-0.2.16.yml exec -T sub2api /app/sub2api --version
   docker compose -f docker-compose.yml -f docker-compose.official-0.2.16.yml logs --tail=100 sub2api
   ```

4. 按前文“已运行官方 0.2.16：安装补丁”安装新包。`apply.sh` 读取的是当前正在运行的官方 `0.2.16` 镜像 ID，所以原 Compose 文件中即使仍写 `0.2.15`，新巡检和专用回滚配置也都会固定到已经验证的官方 `0.2.16`。

如果第二步失败，检查输出后修复即可。不要在数据库已执行 `0.2.16` 迁移后重新加载旧巡检覆盖文件或使用旧包的 `rollback.sh`；它们可能启动旧版程序。新包的回滚脚本仅恢复官方 `0.2.16`。数据库降级属于独立恢复操作，需要结合升级前备份处理。

## 检测规则和性能

模型和推理强度固定为 `gpt-6-astra / XHigh`。可修改巡检间隔、超时、并发、问题、目标 iPhone 代数和账号范围；目标代数不会随日期自动更新。页面配置写入数据库并自动生效。默认每 30 分钟检查，沿用完整回答符合目标型号规则即正常的判定；这是指定回答规则检查，不是通用智力测量。

仅处理启用状态的独立 OpenAI OAuth 账号，包括已经关闭调度的账号；排除 API Key、Agent Identity、影子账号、禁用和已过期账号。每个账号须绑定启用且未过期的代理，检测和必要的令牌刷新均使用该代理。缺少有效代理，或网络、认证失败时保留原调度状态。

账号按每页 200 个读取，只查询巡检或页面需要的字段。结果不改变调度时只执行一次数据库写入；需要切换调度时，在同一个事务提交账号更新与 outbox 调度通知。

## 后续启动和卸载补丁

补丁安装后，应用服务操作须加载巡检覆盖文件：

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml up -d --no-deps sub2api
```

卸载巡检、恢复官方 `0.2.16`：

```sh
sh gpt-monitor-patch-0.2.16/rollback.sh docker-compose.yml sub2api
```

回滚脚本验证专用镜像覆盖文件，并使用原 Compose 文件加 `docker-compose.gpt-monitor.rollback-0.2.16.yml` 重建应用服务。它不会加载巡检挂载、不会仅凭原文件中的旧标签退回 `0.2.15`，也不执行 `down` 或删除数据卷。回滚后应看到官方完整 commit `01842576b3d5c1e2545b5a99ad555d36e28ed306`。已有巡检数据保留；此前巡检修改的账号调度开关不会自动还原，可在账号管理中调整。

卸载后启动官方程序，继续带上专用官方镜像文件：

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.rollback-0.2.16.yml up -d --no-deps sub2api
```

不要清理仍被这两个覆盖文件引用的本机镜像。若安装后的版本核验失败，脚本会保留文件供检查，可运行新包的 `rollback.sh` 恢复官方 `0.2.16`。重新安装前请先回滚、核验原版，再把两个生成文件移至未使用的备份名；脚本不会覆盖已有配置。

## 多个 Compose 文件或自定义选项

原部署若使用多个 `-f`、自定义 `-p` 项目名、`--env-file`、远程 Docker daemon 或多副本，不要直接套用上述简化脚本。保留原命令所有选项，先备份数据库，再用不包含旧巡检挂载的 Compose 配置升级官方 `0.2.16`。

手动安装时先运行 `(cd gpt-monitor-patch-0.2.16 && sha256sum -c SHA256SUMS)`，核验运行中的官方版本及完整 commit，读取容器的完整镜像 ID 和镜像架构，再创建巡检覆盖文件。挂载目标始终是 `/app/sub2api`，示例：

```yaml
services:
  sub2api:
    image: 'sha256:当前官方0.2.16容器的完整镜像ID'
    pull_policy: never
    volumes:
      - type: bind
        source: '/原部署目录/gpt-monitor-patch-0.2.16/bin/linux-amd64/sub2api'
        target: /app/sub2api
        read_only: true
        bind:
          create_host_path: false
```

在原命令的最后追加该文件，仅重建应用服务，安装后核验构建标记 `0184257-gpt-monitor`。另存不包含 `volumes` 的官方 `0.2.16` 镜像覆盖文件供手动回滚使用。回滚时去掉巡检文件，追加固定官方 `0.2.16` 的镜像文件，保留所有原有选项；不要只使用仍写旧版镜像的原配置。远程 Docker 的绑定路径必须存在于 daemon 所在服务器。

部署脚本通过模拟 Docker 命令测试；本地测试不连接服务器、数据库或真实账号。真实账号检测和实际部署需在安装后确认。
