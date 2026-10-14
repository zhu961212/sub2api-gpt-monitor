#!/bin/sh
# Update official 0.2.16 or supported previous patches without overwriting mounted programs.
set -eu
set -f
. "$(dirname -- "$0")/common.sh"
case "$#" in 0) set -- docker-compose.yml sub2api ;; 1) set -- "$1" sub2api ;; 2) ;; *) poll_fail '用法：sh update.sh [docker-compose.yml] [sub2api]' ;; esac
poll_init "$1" "$2"
poll_prepare_recovery_env
for poll_path in "$poll_overlay" "$poll_previous" "$poll_previous_hashes" "$poll_previous_image"; do
  [ ! -e "$poll_path" ] && [ ! -L "$poll_path" ] || poll_fail '新版覆盖文件或更新记录已存在，不会覆盖；请先查看当前版本'
done
[ -f "$poll_bundle/SHA256SUMS" ] || poll_fail '包内缺少 SHA256SUMS'
awk '
  length($1)!=64 || $1~/[^0-9a-f]/ || substr($0,65,2)!="  " {exit 1}
  {name=substr($0,67); if(name!~/^[a-zA-Z0-9_.\/-]+$/ || name~/^\// || name~/(^|\/)\.\.?(\/|$)/ || seen[name]++)exit 1}
  END {if(!seen["update.sh"] || !seen["rollback.sh"] || !seen["manage.sh"] || !seen["common.sh"] || !seen["UPSTREAM_BASE.txt"] || !seen["bin/linux-amd64/sub2api"] || !seen["bin/linux-arm64/sub2api"])exit 1}
' "$poll_bundle/SHA256SUMS" || poll_fail '包内校验清单无效或未覆盖关键文件'
while IFS= read -r poll_checksum || [ -n "$poll_checksum" ]; do
  poll_name=$(printf '%s' "$poll_checksum" | cut -c 67-)
  poll_no_symlinks "$poll_bundle/$poll_name"
  [ -f "$poll_bundle/$poll_name" ] || poll_fail '校验清单文件缺失'
done < "$poll_bundle/SHA256SUMS"
(cd "$poll_bundle" && sha256sum -c SHA256SUMS) || poll_fail '安装包校验失败'
printf '%s\n' "$official_marker" | cmp -s - "$poll_bundle/UPSTREAM_BASE.txt" || poll_fail '安装包基线不符'
for poll_arch in amd64 arm64; do
  poll_candidate="$poll_bundle/bin/linux-$poll_arch/sub2api"
  [ -f "$poll_candidate" ] && [ -x "$poll_candidate" ] || poll_fail '程序缺少执行权限，请在 Linux 使用 tar 解压'
  poll_magic=$(od -An -tx1 -N7 "$poll_candidate" | tr -d ' \n')
  poll_kind=$(od -An -tx1 -j16 -N2 "$poll_candidate" | tr -d ' \n')
  poll_machine=$(od -An -tx1 -j18 -N2 "$poll_candidate" | tr -d ' \n')
  [ "$poll_magic" = 7f454c46020101 ] || poll_fail '程序不是64位小端 ELF'
  case "$poll_kind" in 0200|0300) ;; *) poll_fail 'ELF 程序类型不正确' ;; esac
  case "$poll_arch:$poll_machine" in amd64:3e00|arm64:b700) ;; *) poll_fail '程序架构与目录不匹配' ;; esac
done
poll_container=$(docker compose -f "$poll_base" ps -q "$poll_service") || poll_fail '读取原应用容器失败'
case "$poll_container" in ''|*[!0-9a-f]*) poll_fail '需要原 Compose 项目中唯一运行的应用容器；自定义项目请设置 COMPOSE_PROJECT_NAME 后重试' ;; esac
poll_current=$(docker exec "$poll_container" /app/sub2api --version 2>&1) || poll_fail '读取当前程序版本失败'
poll_version_fields "$poll_current"
[ "$poll_version" = 0.2.16 ] || poll_fail '仅支持当前运行版本 0.2.16'
case "$poll_commit" in
  "$poll_marker") poll_fail '当前已经运行此智商恢复版本，无需重复更新' ;;
  "$official_marker"|0184257-gpt-monitor|0184257-gpt-monitor-v2|0184257-gpt-monitor-poll|0184257-gpt-monitor-patch|0184257-intelligence-v2|0184257-intelligence-recovery-v1) poll_old_commit=$poll_commit ;;
  *) poll_fail '当前构建标记不受支持，需要精确官方0.2.16、巡检v1/v2/poll/patch、智商检测v2或智商恢复v1' ;;
esac
poll_image=$(docker inspect --format '{{.Image}}' "$poll_container") || poll_fail '读取当前镜像失败'
poll_validate_image
poll_underlying=$(docker run --rm --pull never --network none --entrypoint /app/sub2api "$poll_image" --version 2>&1) || poll_fail '无法核验底层官方程序版本'
poll_version_fields "$poll_underlying"
[ "$poll_version" = 0.2.16 ] && [ "$poll_commit" = "$official_marker" ] || poll_fail '底层镜像不是精确官方0.2.16，未修改服务'
poll_project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$poll_container") || poll_fail '读取原项目名失败'
case "$poll_project" in ''|*[!a-z0-9_-]*) poll_fail '无法确认原 Compose 项目名' ;; esac
poll_working=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$poll_container") || poll_fail '读取原项目目录失败'
case "$poll_working" in /*) ;; *) poll_fail '无法确认原项目目录' ;; esac
poll_no_symlinks "$poll_working"
poll_working=$(CDPATH= cd -- "$poll_working" && pwd -P) || poll_fail '原项目目录不存在'
[ "$poll_working" = "$poll_dir" ] || poll_fail '原部署使用不同的 --project-directory，请保留原选项手动更新'
poll_active=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}' "$poll_container") || poll_fail '读取实际 Compose 配置链失败'
case "$poll_active" in ''|'<no value>'|*'
'*|*',,'*|,*|*,) poll_fail '无法确认原 Compose 配置链' ;; esac
poll_env_file=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project.environment_file"}}' "$poll_container") || poll_fail '读取原环境文件标记失败'
case "$poll_env_file" in ''|'<no value>'|"$poll_dir/.env") ;; *) poll_fail '原部署使用自定义 --env-file，请按发布说明保留原选项手动更新' ;; esac
poll_environment="$poll_dir/.env"
if [ -e "$poll_environment" ] || [ -L "$poll_environment" ]; then
  poll_no_symlinks "$poll_environment"
  [ -f "$poll_environment" ] || poll_fail '默认 .env 不是常规文件'
fi
poll_health=$(docker inspect --format '{{.State.Health.Status}}' "$poll_container") || poll_fail '原应用没有可核验的健康检查，请按说明手动更新'
[ "$poll_health" = healthy ] || poll_fail '原应用尚未健康，请先检查现有部署'
poll_mounted=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/app/sub2api"}}{{.Source}}{{println}}{{end}}{{end}}' "$poll_container") || poll_fail '读取当前程序挂载失败'
case "$poll_old_commit" in
  "$official_marker") [ -z "$poll_mounted" ] || poll_fail '官方程序存在额外挂载，请先核对部署' ;;
  *)
    case "$poll_mounted" in /*) ;; *) poll_fail '旧巡检程序挂载路径无效' ;; esac
    case "$poll_mounted" in *'
'*) poll_fail '程序挂载不唯一' ;; esac
    poll_no_symlinks "$poll_mounted"
    [ -f "$poll_mounted" ] || poll_fail '旧巡检程序挂载文件不存在'
    case "$poll_mounted" in *,*|*\"*) poll_fail '旧程序路径含特殊 CSV 字符，请手动更新' ;; esac
    poll_disk_old=$(docker run --rm --pull never --network none --mount "type=bind,src=$poll_mounted,dst=/app/sub2api,readonly" --entrypoint /app/sub2api "$poll_image" --version 2>&1) || poll_fail '无法核验磁盘上的旧程序'
    poll_version_fields "$poll_disk_old"
    [ "$poll_version" = 0.2.16 ] && [ "$poll_commit" = "$poll_old_commit" ] || poll_fail '磁盘旧程序已被替换，无法保证回滚，未修改服务'
    ;;
esac
poll_original_files=$(printf '%s' "$poll_active" | tr ',' '\n')
poll_first=$(printf '%s\n' "$poll_original_files" | sed -n '1p')
[ "$poll_first" = "$poll_base" ] || poll_fail '传入的主 Compose 文件与实际运行配置不匹配'
while IFS= read -r poll_file; do
  case "$poll_file" in /*) ;; *) poll_fail '实际配置链中含非绝对路径' ;; esac
  poll_no_symlinks "$poll_file"
  [ -f "$poll_file" ] || poll_fail '实际运行的 Compose 文件已丢失'
done <<EOF
$poll_original_files
EOF
poll_saved_config_hash=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.config-hash"}}' "$poll_container") || poll_fail '读取运行配置摘要失败'
case "$poll_saved_config_hash" in ''|*[!0-9a-f]*) poll_fail '无法核验原运行配置摘要' ;; esac
poll_original_hash() {
  set -- --project-directory "$poll_dir" -p "$poll_project"
  while IFS= read -r poll_file; do set -- "$@" -f "$poll_file"; done <<EOF
$poll_original_files
EOF
  docker compose "$@" config --hash "$poll_service"
}
poll_hash_output=$(poll_original_hash) || poll_fail '无法计算原 Compose 配置摘要，未修改服务'
poll_calculated_hash=$(printf '%s\n' "$poll_hash_output" | awk -v service="$poll_service" '$1==service {print $2;exit}')
[ "$poll_calculated_hash" = "$poll_saved_config_hash" ] || poll_fail '无法确认当前配置与运行容器一致，可能是配置变化或 Compose 版本差异；请核对或按说明手动更新，未修改服务'
poll_choose_binary
if [ -n "$poll_mounted" ]; then
  case "$poll_mounted" in "$poll_bundle"/*) poll_fail '旧程序挂载已在新包目录内，无法保证独立回滚' ;; esac
  [ ! "$poll_mounted" -ef "$poll_binary" ] || poll_fail '新旧程序不能是同一文件'
fi
# All preflight checks above are read-only. Create only new private records.
(
  umask 077
  set -C
  {
    printf '%s\n' intelligence-recovery-v2-previous-v1 "$poll_service" "$poll_project" "$poll_image" "$poll_old_commit" "$poll_recovery_env_file" "$poll_recovery_env_sha256"
    printf '%s\n' "$poll_original_files"
  } > "$poll_previous"
  poll_image_record_text > "$poll_previous_image"
  {
    sha256sum "$poll_previous" "$poll_previous_image"
    while IFS= read -r poll_file; do sha256sum "$poll_file"; done <<EOF
$poll_original_files
EOF
    if [ -n "$poll_mounted" ]; then sha256sum "$poll_mounted"; fi
    if [ -f "$poll_environment" ]; then sha256sum "$poll_environment"; fi
  } > "$poll_previous_hashes"
  poll_overlay_text > "$poll_overlay"
) || poll_fail '创建更新记录失败；未重建应用服务，保留文件供核对'
poll_load_previous
poll_validate_overlay
poll_compose old config || poll_fail '原配置恢复链校验失败，未重建服务'
poll_compose new config || poll_fail '新版配置校验失败，未重建服务'
poll_restore() {
  printf '新版启动或版本检查失败，正在恢复更新前程序…\n' >&2
  if poll_compose old up; then
    poll_restored=$(poll_compose old version 2>&1) || poll_restored=''
    poll_version_fields "$poll_restored"
    if [ "$poll_version" = 0.2.16 ] && [ "$poll_commit" = "$poll_old_commit" ]; then
      printf '已恢复更新前程序：%s。新文件仍保留供检查。\n' "$poll_old_commit" >&2
    else
      printf '恢复后的版本尚未确认，请查看应用日志；数据库和旧程序未覆盖。\n' >&2
    fi
  else
    printf '自动恢复未能确认健康，请使用本包 rollback.sh 并检查日志。\n' >&2
  fi
  exit 1
}
poll_compose new up || poll_restore
poll_installed=$(poll_compose new version 2>&1) || poll_restore
poll_version_fields "$poll_installed"
[ "$poll_version" = 0.2.16 ] && [ "$poll_commit" = "$poll_marker" ] || poll_restore
printf '\n更新完成：Sub2API 0.2.16，构建标记 %s。\n' "$poll_marker"
printf '原程序与配置已保留；浏览器强制刷新后进入“智商恢复”页面。\n'
printf '后续操作：sh "%s/manage.sh" status "%s" "%s"\n' "$poll_bundle" "$poll_base" "$poll_service"
printf '回滚操作：sh "%s/rollback.sh" "%s" "%s"\n' "$poll_bundle" "$poll_base" "$poll_service"
