#!/bin/sh
# Manage intelligence recovery v2 using the project and configuration chain saved by updater.
set -eu
set -f
. "$(dirname -- "$0")/common.sh"
case "$#" in
  0) set -- status docker-compose.yml sub2api ;;
  1) set -- "$1" docker-compose.yml sub2api ;;
  2) set -- "$1" "$2" sub2api ;;
  3) ;;
  *) poll_fail '用法：sh manage.sh [status|start|logs] [docker-compose.yml] [sub2api]' ;;
esac
poll_requested_action=$1
case "$poll_requested_action" in status|start|logs) ;; *) poll_fail '动作必须为 status、start 或 logs' ;; esac
poll_init "$2" "$3"
poll_load_previous
poll_validate_overlay
(cd "$poll_bundle" && sha256sum -c SHA256SUMS) || poll_fail '新程序包校验失败'
case "$poll_requested_action" in
  logs) poll_compose new logs ;;
  start)
    poll_compose new config || poll_fail '新配置校验失败'
    poll_compose new up || poll_fail '新版启动未能确认健康，请查看日志或执行 rollback.sh'
    poll_started=$(poll_compose new version 2>&1) || poll_fail '读取新版程序失败'
    poll_version_fields "$poll_started"
    [ "$poll_version" = 0.2.16 ] && [ "$poll_commit" = "$poll_marker" ] || poll_fail '新版启动后的构建标记不符'
    printf '%s\n' "$poll_started"
    ;;
  status)
    poll_status=$(poll_compose new version 2>&1) || poll_fail '读取应用版本失败'
    printf '%s\n' "$poll_status"
    poll_version_fields "$poll_status"
    [ "$poll_version" = 0.2.16 ] && [ "$poll_commit" = "$poll_marker" ] || poll_fail '当前程序尚未运行此智商恢复补丁版本；若刚回滚，这是原程序状态'
    ;;
esac
