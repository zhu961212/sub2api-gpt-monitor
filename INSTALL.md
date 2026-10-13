# Sub2API 0.2.15：GPT 账号巡检管理页

安装包：`sub2api-0.2.15-gpt-monitor-ui.tar.gz`。基于上游提交 `ab80abc6d1f929a6864c8804fd077b509d21fda2`，包含 Linux amd64、arm64 程序。

这是内置管理页，直接替换现有容器中的程序。无需插件、公钥、管理员 API Key 或新增容器；普通用户请求继续使用原有转发流程。脚本保留当前镜像，仅重建指定的应用服务，重建时应用会短暂中断。

## 三步安装

1. 将安装包放到**原 Docker Compose 部署目录**，在该目录解压：

   ```sh
   tar -xzf sub2api-0.2.15-gpt-monitor-ui.tar.gz
   ```

2. 在同一目录执行。第一个参数是原 Compose 文件，第二个是服务名，可按实际名称替换：

   ```sh
   sh gpt-monitor-patch/apply.sh docker-compose.yml sub2api
   ```

   脚本会校验文件、确认当前运行版本恰为 `0.2.15`，并按**当前容器镜像架构**选择程序。它生成 `docker-compose.gpt-monitor.yml`，将程序只读挂载到 `/app/sub2api`；已有同名覆盖文件时会停止。保持原 Compose 文件、`.env` 和部署目录不变，且不要移动或删除 `gpt-monitor-patch`。

3. 浏览器强制刷新后台，打开左侧 **GPT 账号巡检**，或直接访问 `/admin/gpt-account-monitor`。检查默认关闭；在页面保存并启用，然后点击“立即检查”查看结果。

页面可修改间隔、超时、并发、模型、问题、目标 iPhone 代数及账号范围。页面保存的配置写入数据库，优先于环境变量与配置文件，自动生效，无需为每次修改重启容器。默认间隔 30 分钟、代数 17；问题按你指定的规则检查，并不代表通用智力测量。

仅处理启用状态的独立 OpenAI OAuth 账号，包含关闭调度的账号；排除 API Key、Agent Identity、影子账号、禁用及已过期账号。每个账号必须绑定启用且未过期的代理，检测和必要的令牌刷新使用该账号代理。缺少有效代理、网络或认证失败时保留调度状态。有效完整回答符合目标型号则开启调度，不符合则关闭，之后继续复检。

## 后续启动和回滚

安装后，应用服务的后续 Compose 操作应同时带上两个文件：

```sh
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml up -d --no-deps sub2api
docker compose -f docker-compose.yml -f docker-compose.gpt-monitor.yml logs --tail=100 sub2api
```

程序为只读挂载，后台自动更新不能直接覆盖它。升级前先回滚，再按目标版本部署；本包只适用于 `0.2.15`。

```sh
sh gpt-monitor-patch/rollback.sh docker-compose.yml sub2api
```

回滚使用原 Compose 文件，仅重建应用服务，不执行 `down`、不删除数据卷。配置和已有检查结果保留；检查已改变的账号调度开关不会自动还原。回滚后只使用原 Compose 文件，保留的覆盖文件不再加载。

## 原部署使用多个 Compose 文件或自定义选项

如果原来使用多个 `-f`、`-p` 项目名、`--env-file`、远程 Docker daemon 或多副本，请保留原命令全部选项并手动操作，不直接运行上述脚本。远程 Docker 的绑定路径必须存在于 daemon 所在服务器。

1. 在解压目录执行 `sha256sum -c SHA256SUMS`。用原 Compose 命令 `exec -T sub2api /app/sub2api --version` 确认当前版本为 `0.2.15`；用 `docker inspect` 获取当前容器镜像 ID，再用 `docker image inspect` 查看其架构。
2. 创建同名覆盖文件；将下面镜像 ID、绝对路径、架构和服务名替换为实际值。保留原命令的全部 Compose 文件顺序，只在最后追加新文件：

   ```yaml
   services:
     sub2api:
       image: 'sha256:当前运行容器的完整镜像ID'
       pull_policy: never
       volumes:
         - type: bind
           source: '/原部署目录/gpt-monitor-patch/bin/linux-amd64/sub2api'
           target: /app/sub2api
           read_only: true
           bind:
             create_host_path: false
   ```

   ```sh
   docker compose -p 原项目名 --env-file 原环境文件 -f 原文件一.yml -f 原文件二.yml -f docker-compose.gpt-monitor.yml up -d --no-deps --force-recreate --pull never --no-build sub2api
   ```

3. 使用相同选项执行 `exec -T sub2api /app/sub2api --version`，确认输出包含 `Sub2API 0.2.15 (commit: ab80abc-gpt-monitor-ui-v1,`，再刷新页面。回滚时只去掉新增的 `-f docker-compose.gpt-monitor.yml`，保留原有全部选项，再重建应用服务。

安装脚本已通过模拟 Docker 命令验证；交付前未连接你的实际 Docker、数据库或账号。
