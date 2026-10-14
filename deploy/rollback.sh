#!/bin/sh
# Restore the program/configuration chain saved before intelligence recovery v2; never alter data.
set -eu
set -f
. "$(dirname -- "$0")/common.sh"
case "$#" in 0) set -- docker-compose.yml sub2api ;; 1) set -- "$1" sub2api ;; 2) ;; *) poll_fail '用法：sh rollback.sh [docker-compose.yml] [sub2api]' ;; esac
poll_init "$1" "$2"
poll_load_previous
poll_compose old config || poll_fail '原配置校验失败，未重建服务'
poll_compose old up || poll_fail '恢复启动未能确认健康，请检查日志；原程序及数据仍保留'
poll_restored=$(poll_compose old version 2>&1) || poll_fail '读取恢复后的程序版本失败'
poll_version_fields "$poll_restored"
[ "$poll_version" = 0.2.16 ] && [ "$poll_commit" = "$poll_old_commit" ] || poll_fail '恢复后的版本尚未确认，请检查应用日志'
printf '%s\n' "$poll_restored"
printf '已恢复更新前程序；数据库与已保存账号调度状态不回退。\n'
printf '保留所有包目录与记录。如需再次启动补丁，用本包 manage.sh start。\n'
