# Sub2API 0.2.16 智商恢复补丁

后台增加“智商恢复”，通过账号绑定代理获取 Codex 路由票据，让正常 OAuth 请求复用有效路由 Cookie。旧问答检测、iPhone 代数规则、复测确认和自动开关调度已删除。

- 单号恢复可使用保存范围外账号；关闭定时恢复后仍可手动恢复。
- 支持批量和定时续取、账号范围、目标网关、超时及有限尝试次数。
- 校验 response.created 模型声明、Fernet 时间及路由 Cookie 有效期。
- 按账号、OAuth 身份、代理及客户端身份隔离，票据存入带期限的 Redis 缓存。
- 新对话只复用 __cflb / __oailb，不注入探针 turn-state；已有对话维持自己的路由。
- 页面不返回原始票据、Token、Cookie 和代理密码；取票不改变调度开关。

“智商恢复”是用户指定的功能名称。票据及路由校验不保证实际模型身份、能力或回答质量。取票会发送小型 gpt-6-astra 请求，可能消耗额度；已有有效额度记录达到 100% 时跳过。

## 开发与本地交付

源码位于源码/sub2api-host-0.2.16，官方基线为 01842576b3d5c1e2545b5a99ad555d36e28ed306。运行 python make_patch.py 导出补丁，python build_release.py --build-frontend 构建含前端的 Linux amd64 / arm64 包及源码 ZIP。

构建标记为 0184257-intelligence-recovery-v1，包目录为 intelligence-recovery-0.2.16-linux-v1。资产文件名保留 sub2api-0.2.16-gpt-monitor-linux.tar.gz 和 sub2api-gpt-monitor.patch。release/ 是本地产物；可在 [GitHub Release](https://github.com/zhu961212/sub2api-gpt-monitor/releases/tag/v0.2.16-intelligence-recovery-v1) 下载 Linux 安装包、源码 ZIP、补丁及校验文件。

## Linux 安装与回滚

进入原 Compose 部署目录（即现有 docker-compose.yml 所在目录），下载本次安装包及校验文件，再依次执行。使用固定版本链接，避免下载到其他版本：

```sh
set -e
release_url='https://github.com/zhu961212/sub2api-gpt-monitor/releases/download/v0.2.16-intelligence-recovery-v1'
curl -fL "$release_url/sub2api-0.2.16-gpt-monitor-linux.tar.gz" -o sub2api-0.2.16-gpt-monitor-linux.tar.gz
curl -fL "$release_url/SHA256SUMS.txt" -o SHA256SUMS.txt
grep '  sub2api-0.2.16-gpt-monitor-linux.tar.gz$' SHA256SUMS.txt | sha256sum -c -
test ! -e intelligence-recovery-0.2.16-linux-v1
tar -xzf sub2api-0.2.16-gpt-monitor-linux.tar.gz
sh intelligence-recovery-0.2.16-linux-v1/update.sh docker-compose.yml sub2api
```

包目录必须独立，已存在时请另选解压位置，不能覆盖挂载中的程序。修改最后两个参数适配 Compose 文件和服务名。支持精确官方 0.2.16、旧巡检 v1/v2/poll/patch 和上一版 0184257-intelligence-v2。

自动更新要求当前容器健康、底层镜像为精确官方 0.2.16，并能核对实际 Compose 配置链。使用自定义项目名时先设置原 COMPOSE_PROJECT_NAME。使用自定义 --env-file、已修改的 Compose 配置或其他不受支持部署方式时，脚本会在重建服务前停止，需要按原部署参数处理。

查看状态：sh intelligence-recovery-0.2.16-linux-v1/manage.sh status docker-compose.yml sub2api

回滚：sh intelligence-recovery-0.2.16-linux-v1/rollback.sh docker-compose.yml sub2api

更新后强制刷新浏览器，进入“智商恢复”，选择账号并保存，然后提交单号或全部恢复。默认不限制票长、不指定某个网关。新版本使用独立 docker-compose.intelligence-recovery-v1.* 记录，保留升级前程序和配置链。

升级后保留新旧包目录及 docker-compose.intelligence-recovery-v1.* 记录。后续启动与查看日志分别使用本包 manage.sh start 和 manage.sh logs，参数仍为原 Compose 文件和服务名。

[项目说明](PROJECT.md) 与 [验证记录](VALIDATION.txt) 提供实现和验收详情。
