# 智商恢复 v2 实现说明

基于官方 Sub2API 0.2.16（01842576b3d5c1e2545b5a99ad555d36e28ed306），对照用户提供 SUCK_MY_ASTRA 本地源码的有限取票、路由 Cookie、动态出口粘性和 WS metadata 实现。无需插件、云函数或数据库迁移。

## 动态住宅会话

新增 proxy_session_mode（none/kookeey/username_sid/template）、proxy_session_ttl_seconds、transport。基础代理从 GPT_ACCOUNT_RECOVERY_PROXY_URL 读取，未覆盖时用账号代理。前端只显示配置状态，API 不接受完整代理 URL 或只读状态。

Kookeey 在密码国家/地区字段后加 8 位 session，不加自动轮换间隔；用户名模式替换 -sid- 字段；模板只允许认证部分含 {session}。无种子重试换新 session，种子沿用旧会话和截止时间。Redis 只新增 session/mode/deadline，不重复保存代理密码。

缓存身份摘要隔离账号、Token、ChatGPT 身份、账号及专用代理、客户端身份、模式/租约与取票通道。身份变化不复用旧路由。票与 Cookie 有效期受会话租约上限约束，种子续取不延长旧租约。

## 取票与业务连接

取票用账号自己的 OAuth 身份，有总时限、尝试数、大小及事件数限制，认证/权限失败停止。SSE 要求完整 response.created 的 id/model；WS 从 101 或 codex.response.metadata 取票，要求完整 response.created 或 metadata.response 的 id/model。两者校验固定模型、Fernet 结构/时间、完整 Cookie pair、网关和最短有效期。

新对话只复用 __cflb/__oailb，不注入探针 turn-state。HTTP 实际代理由同一票据重建。WS RouteFactory 在连接选择和拨号前同步 Cookie 与代理，兼容键包含 Cookie 和实际代理摘要，同 Cookie 不同 session 不误复用；preferred 续链保持原物理连接。

真实 turn-state 与实际 Cookie/session 单独映射。observer 在拨号前用最终路由建私有快照，避免并发取票错绑；业务 metadata 的真实 state 同样记录续链路由，完整状态与凭据不记公开日志。

## 管理与约束

/admin/gpt-account-recovery 支持单号、范围批量、定时、取消过时任务、Redis 租约及共享计划。单号可在范围外，停定时仍可手动。旧问答/iPhone 分类器和自动调度开关逻辑继续保持删除。

专用代理用于恢复和命中路由的业务连接，令牌刷新沿原账号策略。独立恢复上下文保护刷新失败不关闭调度，有效额度 100% 时跳过。结果只含脱敏状态、时间、网关、长度及错误分类，保留管理员认证和 Step-up。

传输调试日志中的代理地址、缓存键和底层错误使用短摘要，避免密码随错误泄漏。

## 可选跨账号路由候选

share_route_cookies 默认关闭；share_route_donor_account_ids 可指定供体。共享池只含 Cookie pair、网关、到期时间、代理配置摘要和兼容时可复用的 session，不包含 OAuth、账号标识或 turn-state。候选池有数量/TTL/体积限制，来源配置变化隔离旧池。

候选只用于取票种子，不能直接当接收账号的业务票据。接收者以自己的 OAuth、身份头和代理发一次有限验证；成功后只保存自己的票和 identity 缓存。不同代理配置丢弃供体 session，仅借 Cookie。验证失败计入原预算，后续可自身裸取票，不改供体或调度。业务 HTTP/WS 仍按账号及真实 turn 隔离。

2026-10-15 有限线上对照共 4 次（A1/B3），使用用户导出文件各自代理。B 借 A 路由 Cookie 可完成响应；B 裸请求与自身路由也都成功，全部模型声明一致。该结果没有证明回答能力恢复，也不把 Cookie 未重发当作实际网关身份的独立证明。

## 构建与交付

标记 0184257-intelligence-recovery-v2，目录 intelligence-recovery-0.2.16-linux-v2，资产名保持兼容。独立 v2 Compose 记录支持 v1 及全部原支持版本升级/回滚。GPT_RECOVERY_ENV_FILE 通过 raw env_file 注入私密值，需 Compose >=2.30，只记录路径和摘要，原链可独立回滚。

make_patch.py 用临时 Git index 验证精确基线应用后的源码树。build_release.py --build-frontend 验证前端、Linux双架构 ELF、TAR 内容权限、源码 ZIP 和 SHA256。源码 HEAD 保持官方基线，外层 Git 提交补丁、脚本、说明和校验。

## 证据边界

“智商恢复”是功能名称。票长、声明、state-echo、网关与出口不能证明实际模型能力。本地测试验证协议、隔离及续链，供应商会话也不能保证物理 IP 永远不变。线上账号取票成功率及回答能力未由本地测试证明。
