# Sub2API 0.2.16 智商检测与账号调度补丁

在官方 Sub2API 上增加单号智商检测、定时巡检和账号调度开关。只发布 Linux 程序，包含 amd64、arm64 两种架构，安装时自动选择。

- 账号行尾点击“智商测试”，单独检测并调整该账号调度。
- 自动巡检按到期时间逐个执行，检测结束后间隔 5 秒。
- 需要改变调度时，约 5 分钟后复测；两次有效结果一致才关闭或恢复。
- 使用账号绑定代理；含糊回答、网络、认证或代理失败时保持原调度。

检测固定使用 `gpt-6-astra / XHigh`，按后台配置的期望 iPhone 代数判定。

## Linux 服务器更新

支持精确官方 0.2.16，以及对应巡检 v1、v2、poll 构建。进入原 Compose 部署目录执行：

```sh
set -e
curl -fL https://github.com/zhu961212/sub2api-gpt-monitor/releases/latest/download/sub2api-0.2.16-gpt-monitor-linux.tar.gz -o sub2api-0.2.16-gpt-monitor-linux.tar.gz
curl -fL https://github.com/zhu961212/sub2api-gpt-monitor/releases/latest/download/SHA256SUMS.txt -o gpt-monitor-SHA256SUMS.txt
grep '  sub2api-0.2.16-gpt-monitor-linux.tar.gz$' gpt-monitor-SHA256SUMS.txt | sha256sum -c -
test ! -e gpt-monitor-patch-0.2.16-linux
tar -xzf sub2api-0.2.16-gpt-monitor-linux.tar.gz
sh gpt-monitor-patch-0.2.16-linux/update.sh docker-compose.yml sub2api
```

Compose 文件或服务名不同，替换最后两个参数。包目录已存在时，使用新的独立解压位置并保留包目录名称；不要覆盖正在挂载的旧程序。

检查、查看日志、启动和回滚：

```sh
sh gpt-monitor-patch-0.2.16-linux/manage.sh status docker-compose.yml sub2api
sh gpt-monitor-patch-0.2.16-linux/manage.sh logs docker-compose.yml sub2api
sh gpt-monitor-patch-0.2.16-linux/manage.sh start docker-compose.yml sub2api
sh gpt-monitor-patch-0.2.16-linux/rollback.sh docker-compose.yml sub2api
```

成功后版本标记为 `0184257-gpt-monitor-patch`。浏览器强制刷新，在“GPT 账号巡检”保存规则并启用。单号测试在自动巡检暂停时也可使用。

更新器保留原 Compose 配置链和旧程序，只重建应用服务，启动失败时恢复旧程序。复用原数据库、Redis、账号和规则，不新增数据库迁移。

## 开发与说明

[项目文档](PROJECT.md) 说明实现、目录和构建步骤。[源码补丁](sub2api-gpt-monitor.patch) 对应官方精确基线 `01842576b3d5c1e2545b5a99ad555d36e28ed306`。Release 提供完整源码 ZIP 和校验值。

开发源码位于 `源码/sub2api-host-0.2.16`。`python make_patch.py` 导出补丁，`python build_release.py` 构建 Linux 包；修改前端后先安装依赖，再运行 `python build_release.py --build-frontend`。

验证见 [VALIDATION.txt](VALIDATION.txt)。本次未连接真实账号或部署到服务器。
