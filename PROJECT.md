# 项目文档

## 目标与功能

在官方 Sub2API 0.2.16 上打补丁，实现 GPT OAuth 账号智商检测与调度。复用宿主后台、代理、令牌刷新、数据库、Redis 和调度，无需额外服务、插件或容器。官方基线为 `01842576b3d5c1e2545b5a99ad555d36e28ed306`，程序版本保持 `0.2.16`，构建标记为 `0184257-gpt-monitor-patch`。仅交付 Linux amd64、arm64。

| 入口 | 行为 |
| --- | --- |
| 账号行尾或菜单的“智商测试” | 单号检测，需要改变调度时自动复测确认 |
| GPT 账号巡检页 | 保存规则、范围、间隔及启停自动巡检，查看检测与调度状态 |
| 自动巡检 | 每次读取最早到期账号，检测结束后至少间隔 5 秒 |
| 顺序测试全部 | 按保存范围观察结果，不改变调度 |

固定请求 `gpt-6-astra / xhigh`。明确符合配置的期望 iPhone 代数判为正常，明确为另一代判为异常；含糊、拒答、混合答案和请求错误均不改变调度。这是固定回答规则，不是智力评分。

需要切换调度时，首次记录待确认状态，约 5 分钟后复测。两次一致才关闭或开启调度，第二样本须在首次的 5–10 分钟窗口内。单号的二次失败、相反结果或过期会结束任务，不无限追加检测。单号测试可在自动巡检关闭或账号不在范围时完成，不修改全局范围。停止前端查询不取消已提交的服务端任务。

## 实现与精简

后端 `gpt_account_monitor_service.go` 负责串行调度与确认，`gpt_account_monitor_probe.go` 通过宿主 OpenAI 请求入口检测，`gpt_account_monitor_verdict.go` 判定回答。结果和计划存入账号现有 `extra` 字段，配置存入现有 settings，不增加数据库迁移。

请求使用账号绑定的有效代理，复用宿主令牌刷新与客户端身份。Redis 租约避免多副本重复检测，账号条件更新防止覆盖检测期间改变的状态，outbox 通知调度更新。

前端复用官方后台，新增巡检页、共享单号查询和结果弹窗，没有新增 npm 依赖。旧判定实现已删除，测试辅助函数已移出生产代码；部署收敛为同一套四个脚本。

## 目录

```text
README.md                  服务器更新入口
PROJECT.md                 项目说明
sub2api-gpt-monitor.patch   官方基线源码补丁
make_patch.py              隔离 Git index 导出并验证补丁
build_release.py           构建 Linux 安装包和完整源码 ZIP
deploy/                    update/manage/rollback/common 脚本
VALIDATION.txt             验证记录
源码/sub2api-host-0.2.16/   当前开发源码，Git 已独立
release/                   Linux 包、源码 ZIP、校验文件
待删除/                    删除受阻后移出的资料，可手动删除
```

旧源码、参考项目、历史包和多版本发布脚本已移出。当前源码不再引用“待删除”，前端依赖需要时重新安装。`源码/`、`release/`、`待删除/` 和本地工具不进入 GitHub 提交；完整源码作为 Release 附件提供。

## 应用补丁与构建

在干净的官方源码根目录：

```sh
git checkout --detach 01842576b3d5c1e2545b5a99ad555d36e28ed306
git apply --check /path/to/sub2api-gpt-monitor.patch
git apply /path/to/sub2api-gpt-monitor.patch
pnpm --dir frontend install --frozen-lockfile
pnpm --dir frontend build
cd backend
CGO_ENABLED=0 go build -tags embed -trimpath \
  -ldflags '-s -w -X main.Version=0.2.16 -X main.Commit=0184257-gpt-monitor-patch -X main.BuildType=release' \
  -o sub2api ./cmd/server
./sub2api --version
```

前端输出到 `backend/internal/web/dist`，通过 `embed` 编译进程序。Release 完整源码 ZIP 可解压到本项目 `源码/` 下；重新导出补丁需建立上述官方基线 Git 仓库。Go、Node 版本要求见源码 `backend/go.mod` 和官方 Dockerfile。

`make_patch.py` 仅收集前后端与配置示例，使用临时 index 验证应用后的树一致，保留真实 index。`build_release.py` 默认复用前端 dist；`--build-frontend` 检查 i18n、类型并重建。

## 更新、回滚和验收

更新命令见 README。脚本只识别精确官方 0.2.16 及对应旧巡检构建，核验包、架构与原配置后重建应用服务。原 Compose 顺序、项目名、镜像和程序保留，启动或版本核验失败尝试恢复。回滚不回退数据库或账号调度状态；保留安装目录和生成的记录。自定义 `--env-file`、远程 Docker 或脚本无法识别的部署，请保持原 Compose 选项手动挂载同一 Linux 程序。

定向后端回归、前端测试、类型检查、生产构建、Linux 交叉编译和假 Docker 更新/回滚验证已通过。未连接真实账号、PostgreSQL 或用户服务器；安装后用一个绑定有效代理的账号执行“智商测试”验收，详情见 `VALIDATION.txt`。
