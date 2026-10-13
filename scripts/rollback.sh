#!/bin/sh
# Recreate only the existing application service using its original Compose file.
set -eu

fail() { printf '回滚失败：%s\n' "$*" >&2; exit 1; }
[ "$#" -le 2 ] || fail '用法：sh gpt-monitor-patch/rollback.sh docker-compose.yml [sub2api]'
compose_file=docker-compose.yml
service=sub2api
if [ "$#" -ge 1 ]; then compose_file=$1; fi
if [ "$#" -ge 2 ]; then service=$2; fi
case "$service" in ''|*[!a-zA-Z0-9_.-]*) fail '服务名无效' ;; esac
[ -f "$compose_file" ] || fail '找不到原 Compose 文件；请在原部署目录执行'
compose_dir=$(CDPATH= cd -- "$(dirname -- "$compose_file")" && pwd -P)
[ "$(pwd -P)" = "$compose_dir" ] || fail '请先进入原 Compose 文件所在目录'
compose_file="$compose_dir/$(basename -- "$compose_file")"
command -v docker >/dev/null 2>&1 || fail '找不到 docker 命令'
docker compose version >/dev/null 2>&1 || fail '需要 Docker Compose v2'
docker compose -f "$compose_file" config --quiet || fail '原 Compose 配置检查失败'
docker compose -f "$compose_file" up -d --no-deps --force-recreate --pull never --no-build "$service" || fail '服务重建失败，请查看原 Compose 配置和容器日志'
printf '\n已使用原 Compose 配置重建应用服务。未执行 down，也未删除数据卷。\n'
printf '以后只使用原 Compose 文件；保留的 docker-compose.gpt-monitor.yml 不再加载。\n'
printf '此前检查修改的账号调度开关不会自动还原，请按需在账号管理中调整。\n'
