# Sub2API 0.2.16 智商检测与账号调度补丁

在官方 Sub2API 后台集中提供智商检测、定时检测和账号调度。只发布 Linux amd64、arm64，安装时自动选择架构。

- 所有检测入口集中在“智商检测”页（原“GPT 账号巡检”），账号管理页已移除检测入口。
- 使用额度达到 100% 时自动跳过，不发起检测请求，不改变调度；额度恢复后可再次检测。
- 自动巡检按到期时间逐个执行，检测结束后间隔 5 秒。
- 需要改变调度时，约 5 分钟后复测；两次有效结果一致才关闭或恢复。
- 使用账号绑定代理；含糊回答、网络、认证或代理失败时保持原调度。

检测固定使用 `gpt-6-astra / XHigh`，按后台配置的期望 iPhone 代数判定。

## Linux 服务器更新

支持精确官方 0.2.16、对应巡检 v1/v2/poll，以及上一版 `0184257-gpt-monitor-patch`。进入原 Compose 部署目录执行：

```sh
set -e
release_url=https://github.com/zhu961212/sub2api-gpt-monitor/releases/download/v0.2.16-intelligence-check-v2
curl -fL "$release_url/sub2api-0.2.16-gpt-monitor-linux.tar.gz" -o sub2api-0.2.16-gpt-monitor-linux.tar.gz
curl -fL "$release_url/SHA256SUMS.txt" -o intelligence-v2-SHA256SUMS.txt
grep '  sub2api-0.2.16-gpt-monitor-linux.tar.gz$' intelligence-v2-SHA256SUMS.txt | sha256sum -c -
test ! -e intelligence-check-0.2.16-linux-v2
tar -xzf sub2api-0.2.16-gpt-monitor-linux.tar.gz
sh intelligence-check-0.2.16-linux-v2/update.sh docker-compose.yml sub2api
```

Compose 文件或服务名不同，替换最后两个参数。新包使用独立目录和 `docker-compose.intelligence-v2.*` 记录，可直接升级上一版；保留旧包和旧覆盖文件，以便回滚。新包目录已存在时停止，另选独立解压位置并保留目录名称，不要覆盖挂载中的程序。

检查、查看日志、启动和回滚：

```sh
sh intelligence-check-0.2.16-linux-v2/manage.sh status docker-compose.yml sub2api
sh intelligence-check-0.2.16-linux-v2/manage.sh logs docker-compose.yml sub2api
sh intelligence-check-0.2.16-linux-v2/manage.sh start docker-compose.yml sub2api
sh intelligence-check-0.2.16-linux-v2/rollback.sh docker-compose.yml sub2api
```

成功后版本标记为 `0184257-intelligence-v2`。浏览器强制刷新，进入“智商检测”保存规则并启用自动检测，也可在该页检测单个账号。

更新器保留原 Compose 配置链和旧程序，只重建应用服务，启动失败时恢复旧程序。复用原数据库、Redis、账号和规则，不新增数据库迁移。

## 开发与说明

[项目文档](PROJECT.md) 说明实现、目录和构建步骤。[源码补丁](sub2api-gpt-monitor.patch) 对应官方精确基线 `01842576b3d5c1e2545b5a99ad555d36e28ed306`。Release 提供完整源码 ZIP 和校验值。

开发源码位于 `源码/sub2api-host-0.2.16`。`python make_patch.py` 导出补丁，`python build_release.py` 构建 Linux 包；修改前端后先安装依赖，再运行 `python build_release.py --build-frontend`。

本轮验证记录见 [VALIDATION.txt](VALIDATION.txt)。
