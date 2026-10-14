# 智商恢复实现说明

基于官方 Sub2API 0.2.16（01842576b3d5c1e2545b5a99ad555d36e28ed306），参考用户指定的 spumon1/SUCK_MY_ASTRA 有限取票、模型声明校验及路由 Cookie 复用逻辑，在宿主 Go 服务内实现。无需插件、云函数、额外容器或数据库迁移。

## 恢复流程

/admin/gpt-account-recovery 替代旧 /admin/gpt-account-monitor。支持账号范围、间隔、超时、尝试上限、网关、票长、有效期、手动单号及批量恢复。自动恢复通过 Redis 租约和共享计划协调多实例；写操作保留管理员认证及 Step-up。

使用账号自己的 OAuth 凭据和有效绑定代理，复用令牌刷新、上游传输及 TLS 配置，向 Codex Responses 发送小型 ping 流式请求。次数和总时限均有边界；认证或权限失败结束，错误只返回脱敏分类。读取合法 response.created 后关闭响应，不等待完整答案。

要求声明模型为 gpt-6-astra、response.id 存在、票据符合 Fernet 结构且未过期、Cookie 配对完整有效及网关匹配。默认 gateway=any、ticket_length=0，避免依赖固定 780 长度或某个网关的未经证实能力判断。JWT 过期时间只是上游声明，本地解析不构成签名验证。

## 正常请求接入与旧功能删除

Redis 缓存键隔离账号 ID、Token、ChatGPT 身份、代理、客户端身份及头覆盖配置。业务命中有效票据时仅带 __cflb / __oailb，不混入登录 Cookie。探针 turn-state 只用于观测，不能跨对话注入；真实回合使用自己的状态和配对路由，WebSocket 连接复用核对 Cookie 摘要。

配置保存在 gpt_account_recovery_config，公开结果位于 extra.gpt_account_recovery，只有时间、状态、网关、长度和脱敏错误。原始票据仅在有期限的 Redis 缓存中。账号凭据或代理变化后旧缓存不会复用。已有有效额度达到 100% 时跳过；取票成功或失败不改变调度。

旧问答、iPhone 代数分类器、确认窗口、二次复测、检测接口、组件和对应测试已删除。旧配置不自动启用恢复；新结果写入时移除该账号旧 gpt_account_monitor 结果。旧版本已关闭的调度开关保留实际状态，管理员可按需要调整。

## 核心文件及构建

gpt_account_recovery_service.go 管理任务和配置；mint.go 取票及协议解析；identity.go / transport.go 处理凭据及代理；openai_recovery_routing.go 接入正常 HTTP/WS；repository recovery 文件负责公开结果和 Redis 缓存。前端 GPTAccountRecoveryView.vue 与 gptAccountRecovery.ts 提供集中恢复入口。

python make_patch.py 使用临时 Git index 验证补丁应用于官方精确基线后得到一致源码树，不改变真实 index。python build_release.py --build-frontend 构建 Linux amd64 / arm64 并内嵌界面，标记 0184257-intelligence-recovery-v1。校验 ELF、TAR 内容和权限、源码 ZIP 完整性及 SHA256。

本地产物在 release/。源码、工具和产物按现有规则不进入外层 Git；外层保存完整补丁、脚本、文档及校验值。独立安装目录和 Compose 记录支持上一版升级与回滚。

## 证据边界

“智商恢复”是后台操作名称。票长、Fernet 结构、网关或模型声明均不能独立证明实际模型身份或能力。不移植按状态长度判断能力、跨回合注票或跨账号全局共享路由。真实代理能否获得合格票据取决于上游；本地测试以可控响应验证协议、隔离及失败处理。
