# Sub2API 0.2.16 智商恢复补丁 v2

在官方 Sub2API 0.2.16 中内置有限取票、路由 Cookie 复用及动态住宅会话。无需 CPA 插件、FC 云函数、额外容器或数据库迁移。

v2 修复动态住宅取票与业务请求未绑定同一出口会话的问题：失败重试换会话，成功后 HTTP、WS 与真实对话续链复用同一会话。新对话不注入探针 turn-state。支持 Kookeey、用户名 -sid-、认证模板 {session}，支持 SSE / WebSocket 取票和 WS metadata。

“智商恢复”是后台功能名。票长、网关及模型声明是协议检查，不保证实际模型身份或回答能力。

## 借路由 Cookie

可显式启用“共享路由 Cookie”，并选择供体账号。先执行供体单号恢复，再执行接收账号恢复。只借 __cflb/__oailb 候选；接收者始终用自己的 OAuth 和自己的代理重新验证，成功后保存到自身缓存，不共享供体 Token、账号身份或 turn-state。

供体名单为空表示所有通过协议验收的来源，不表示系统已鉴定账号能力；需要固定来源时请明确选择供体。切换来源配置隔离旧候选。不同基础代理只借 Cookie，不能把供体代理会话或凭据复制给接收者。

2026-10-15 用户授权的小型对照：供体 1 次、接收者 3 次，均使用导出文件各自绑定的 SOCKS5 代理。接收者借供体 Cookie 返回 200/完整响应且未重发路由 Cookie；裸请求与自身 Cookie 对照也均成功。所有响应声明同一请求模型，仅说明当次协议兼容，没有测得能力改善。

## 版本与下载

版本：v0.2.16-intelligence-recovery-v2；标记：0184257-intelligence-recovery-v2；包目录：intelligence-recovery-0.2.16-linux-v2。

[GitHub Release](https://github.com/zhu961212/sub2api-gpt-monitor/releases/tag/v0.2.16-intelligence-recovery-v2) 包含 Linux amd64/arm64 安装包、完整源码 ZIP、精确基线补丁及 SHA256。支持官方 0.2.16、旧巡检/检测版和恢复 v1 升级。

## 配置动态住宅

真实代理 URL 只保存在服务器私密文件，不写 GitHub 或前端。创建 recovery-proxy.env，示例：

~~~dotenv
GPT_ACCOUNT_RECOVERY_PROXY_URL=http://USER:SECRET-US@gate.example:1000
GPT_ACCOUNT_RECOVERY_PROXY_SESSION_MODE=kookeey
GPT_ACCOUNT_RECOVERY_PROXY_SESSION_TTL_SECONDS=600
GPT_ACCOUNT_RECOVERY_TRANSPORT=sse
~~~

替换示例地址、账号和密码，保留供应商国家字段。不要预置 session 或自动轮换间隔，程序追加 8 位随机会话。特殊字符按标准 URL 编码；代理协议可为 HTTP/HTTPS/SOCKS5/SOCKS5H，需匹配实际入口。示例不含用户真实凭据。

~~~sh
chmod 600 recovery-proxy.env
~~~

专用代理用于取票及命中票据的业务连接，令牌刷新沿用原账号代理策略。未设置覆盖时使用账号绑定代理。专用配置无效时恢复明确失败，不偷偷直连；没命中恢复路由的业务请求保留宿主正常路径。

600 秒是本地租约，不要求供应商自动换 IP；票和 Cookie 有效期受租约、配置及上游声明限制。过期影响新建连接，进行中的 preferred WS 续链保持原物理连接。

## 更新现有 Compose 部署

进入原 docker-compose.yml 所在目录，放好私密 recovery-proxy.env，执行：

~~~sh
set -e
release_url='https://github.com/zhu961212/sub2api-gpt-monitor/releases/download/v0.2.16-intelligence-recovery-v2'
curl -fL "$release_url/sub2api-0.2.16-gpt-monitor-linux.tar.gz" -o sub2api-0.2.16-gpt-monitor-linux.tar.gz
curl -fL "$release_url/SHA256SUMS.txt" -o SHA256SUMS.txt
grep '  sub2api-0.2.16-gpt-monitor-linux.tar.gz$' SHA256SUMS.txt | sha256sum -c -
test ! -e intelligence-recovery-0.2.16-linux-v2
tar -xzf sub2api-0.2.16-gpt-monitor-linux.tar.gz
GPT_RECOVERY_ENV_FILE="$PWD/recovery-proxy.env" \
  sh intelligence-recovery-0.2.16-linux-v2/update.sh docker-compose.yml sub2api
~~~

最后两参数为原 Compose 文件和服务名。私密 env 接入要求 Docker Compose 2.30.0+，raw 格式保留密码中的 $ 等字符；不传私密文件时保留原要求。

如果沿用导入账号各自绑定的代理，不设置专用动态代理覆盖，直接执行：

~~~sh
sh intelligence-recovery-0.2.16-linux-v2/update.sh docker-compose.yml sub2api
~~~

这种方式不需要 recovery-proxy.env，固定代理的会话模式选 none。仅当需要专用动态住宅时才使用上面的 GPT_RECOVERY_ENV_FILE 命令。

脚本核对容器健康、精确官方基础镜像及配置链。自定义项目名先设原 COMPOSE_PROJECT_NAME；自定义 --env-file 等无法可靠恢复的部署会在重建前停止，应按原参数处理。

保留新旧包目录和 docker-compose.intelligence-recovery-v2.* 记录，不覆盖正在挂载的旧包。私密文件仅在本机记录路径与摘要；之后修改文件会阻止新版重新启动，需核对记录。文件丢失仍可回滚原链。

## 更新后操作

1. 强制刷新浏览器，进入“智商恢复”。
2. 确认已配置服务器恢复代理，会话模式选 Kookeey，租约先用 600 秒。
3. 取票先选 SSE，需要时单独选择 WebSocket；它不会修改业务执行器。
4. 选择账号、保存，先单号恢复，再按需启用批量/定时。
5. 默认 gateway=any、ticket_length=0；查看协议验收、有效期和脱敏错误。
6. 借路由时启用共享开关、明确供体，先供体单号恢复，再接收账号；使用原绑定代理时保持会话模式 none。

后台已保存设置优先于环境默认，升级不覆盖旧配置，需在页面核对模式。恢复使用账号自己的 OAuth 身份；有效额度记录达到 100% 时跳过。小型取票请求可能消耗额度，恢复不改变调度开关。

~~~sh
sh intelligence-recovery-0.2.16-linux-v2/manage.sh status docker-compose.yml sub2api
sh intelligence-recovery-0.2.16-linux-v2/manage.sh logs docker-compose.yml sub2api
sh intelligence-recovery-0.2.16-linux-v2/manage.sh start docker-compose.yml sub2api
# 回滚到升级前程序及配置链
sh intelligence-recovery-0.2.16-linux-v2/rollback.sh docker-compose.yml sub2api
~~~

## 开发与验证

源码：源码/sub2api-host-0.2.16；精确基线：01842576b3d5c1e2545b5a99ad555d36e28ed306。python make_patch.py 导出并验证；python build_release.py --build-frontend 构建嵌入前端的双架构包及完整源码 ZIP。

源码、私密配置和产物不进入外层 Git。原始票据仅存有期限 Redis 缓存；公开结果不返回票据、Token、Cookie 或密码。调试传输日志使用摘要。

[实现说明](PROJECT.md) 与 [验证记录](VALIDATION.txt) 记录行为、测试和实测边界。
