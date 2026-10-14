#!/bin/sh
# Shared guarded Compose operations for the 0.2.16 patch package.
poll_marker=0184257-intelligence-recovery-v2
official_marker=01842576b3d5c1e2545b5a99ad555d36e28ed306
poll_fail() { printf '操作失败：%s\n' "$*" >&2; exit 1; }
poll_no_symlinks() {
  poll_checked=$1
  case "$poll_checked" in /*) ;; *) poll_checked="$(pwd -P)/$poll_checked" ;; esac
  while [ "$poll_checked" != / ]; do
    [ ! -L "$poll_checked" ] || poll_fail '配置、程序和记录路径不能包含符号链接'
    poll_checked=$(dirname -- "$poll_checked")
  done
}
poll_init() {
  poll_base=$1
  poll_service=$2
  case "$poll_service" in ''|*[!a-zA-Z0-9_.-]*) poll_fail '服务名无效' ;; esac
  case "$poll_base$0" in *'
'*) poll_fail '路径不能包含换行符' ;; esac
  poll_no_symlinks "$poll_base"
  poll_no_symlinks "$0"
  [ -f "$poll_base" ] || poll_fail '找不到原 Compose 文件'
  poll_dir=$(CDPATH= cd -- "$(dirname -- "$poll_base")" && pwd -P)
  [ "$(pwd -P)" = "$poll_dir" ] || poll_fail '请在原 Compose 文件所在目录执行'
  poll_base="$poll_dir/$(basename -- "$poll_base")"
  poll_bundle=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
  [ "$(basename -- "$poll_bundle")" = intelligence-recovery-0.2.16-linux-v2 ] || poll_fail '请保留独立的 intelligence-recovery-0.2.16-linux-v2 包目录'
  poll_overlay="$poll_dir/docker-compose.intelligence-recovery-v2.yml"
  poll_previous="$poll_dir/docker-compose.intelligence-recovery-v2.previous.txt"
  poll_previous_hashes="$poll_dir/docker-compose.intelligence-recovery-v2.previous.sha256"
  poll_previous_image="$poll_dir/docker-compose.intelligence-recovery-v2.previous-image.yml"
  poll_recovery_env_file=''
  poll_recovery_env_sha256=''
  for poll_command in docker awk sed cut cmp sha256sum od tr wc; do
    command -v "$poll_command" >/dev/null 2>&1 || poll_fail "缺少 $poll_command"
  done
  docker compose version >/dev/null 2>&1 || poll_fail '需要 Docker Compose'
  poll_help=$(docker compose up --help) || poll_fail '无法检查 Compose 启动选项'
  case "$poll_help" in *--wait-timeout*) ;; *) poll_fail '需要支持 --wait 与 --wait-timeout 的 Docker Compose' ;; esac
}
poll_require_raw_env() {
  poll_compose_version=$(docker compose version --short) || poll_fail '无法检查 Compose env_file 支持'
  printf '%s\n' "$poll_compose_version" | awk '
    {sub(/^v/, ""); if ($0 !~ /^[0-9]+\.[0-9]+\.[0-9]+/) exit 1; split($0, v, "."); if (v[1] > 2 || (v[1] == 2 && v[2] >= 30)) ok=1}
    END {if (!ok) exit 1}
  ' || poll_fail '使用 GPT_RECOVERY_ENV_FILE 需要 Docker Compose 2.30.0 或更新版本（env_file format: raw）'
}
poll_recovery_env_fields() {
  if [ -z "$poll_recovery_env_file" ]; then
    [ -z "$poll_recovery_env_sha256" ] || poll_fail '私密环境文件记录损坏'
    return
  fi
  case "$poll_recovery_env_file" in /*) ;; *) poll_fail '私密环境文件路径必须是绝对路径' ;; esac
  case "$poll_recovery_env_file" in *'
'*|*"$(printf '\r')"*) poll_fail '私密环境文件路径不能包含换行符' ;; esac
  [ "$(printf '%s' "$poll_recovery_env_sha256" | wc -c | tr -d ' ')" -eq 64 ] || poll_fail '私密环境文件摘要损坏'
  case "$poll_recovery_env_sha256" in *[!0-9a-f]*) poll_fail '私密环境文件摘要损坏' ;; esac
}
poll_validate_recovery_env() {
  poll_recovery_env_fields
  [ -n "$poll_recovery_env_file" ] || return 0
  poll_no_symlinks "$poll_recovery_env_file"
  [ -f "$poll_recovery_env_file" ] && [ -r "$poll_recovery_env_file" ] || poll_fail '私密环境文件不存在或不可读；原部署仍可回滚'
  poll_actual_env_sha256=$(sha256sum "$poll_recovery_env_file" | cut -c 1-64) || poll_fail '无法校验私密环境文件'
  [ "$poll_actual_env_sha256" = "$poll_recovery_env_sha256" ] || poll_fail '私密环境文件已修改；请核对部署配置，原部署仍可回滚'
  poll_require_raw_env
}
poll_prepare_recovery_env() {
  poll_recovery_env_file=${GPT_RECOVERY_ENV_FILE:-}
  poll_recovery_env_sha256=''
  [ -n "$poll_recovery_env_file" ] || return 0
  case "$poll_recovery_env_file" in *'
'*|*"$(printf '\r')"*) poll_fail '私密环境文件路径不能包含换行符' ;; esac
  poll_no_symlinks "$poll_recovery_env_file"
  poll_private_env_dir=$(CDPATH= cd -- "$(dirname -- "$poll_recovery_env_file")" && pwd -P) || poll_fail '私密环境文件目录不存在'
  poll_recovery_env_file="$poll_private_env_dir/$(basename -- "$poll_recovery_env_file")"
  [ -f "$poll_recovery_env_file" ] && [ -r "$poll_recovery_env_file" ] || poll_fail 'GPT_RECOVERY_ENV_FILE 必须指向已存在且可读的常规文件'
  poll_recovery_env_sha256=$(sha256sum "$poll_recovery_env_file" | cut -c 1-64) || poll_fail '无法校验私密环境文件'
  poll_validate_recovery_env
}
poll_version_fields() {
  poll_version=$(printf '%s\n' "$1" | awk '/Sub2API / {for(i=1;i<NF;i++)if($i=="Sub2API"){print $(i+1);exit}}')
  poll_commit=$(printf '%s\n' "$1" | awk '/Sub2API / {for(i=1;i<=NF;i++)if($i=="Sub2API"){if(i+3<=NF && $(i+2)=="(commit:"){x=$(i+3);sub(/,$/,"",x);print x}exit}}')
}
poll_validate_image() {
  case "$poll_image" in sha256:*) ;; *) poll_fail '镜像 ID 不完整' ;; esac
  poll_hash=$(printf '%s' "$poll_image" | cut -c 8-)
  poll_hash_length=$(printf '%s' "$poll_hash" | wc -c | tr -d ' ')
  [ "$poll_hash_length" -eq 64 ] || poll_fail '镜像 ID 不完整'
  case "$poll_hash" in *[!0-9a-f]*) poll_fail '镜像 ID 无效' ;; esac
}
poll_image_record_text() {
  cat <<EOF
# Pinned previous application image for the patch updater.
services:
  '$poll_service':
    image: '$poll_image'
    pull_policy: never
EOF
}
poll_load_previous() {
  for poll_path in "$poll_previous" "$poll_previous_hashes" "$poll_previous_image"; do
    poll_no_symlinks "$poll_path"
    [ -f "$poll_path" ] || poll_fail '缺少升级时保存的原配置记录'
  done
  exec 3< "$poll_previous"
  IFS= read -r poll_format <&3 || poll_fail '原配置记录损坏'
  IFS= read -r poll_saved_service <&3 || poll_fail '原配置记录损坏'
  IFS= read -r poll_project <&3 || poll_fail '原配置记录损坏'
  IFS= read -r poll_image <&3 || poll_fail '原配置记录损坏'
  IFS= read -r poll_old_commit <&3 || poll_fail '原配置记录损坏'
  IFS= read -r poll_recovery_env_file <&3 || poll_fail '私密环境文件记录损坏'
  IFS= read -r poll_recovery_env_sha256 <&3 || poll_fail '私密环境文件记录损坏'
  [ "$poll_format" = intelligence-recovery-v2-previous-v1 ] && [ "$poll_saved_service" = "$poll_service" ] || poll_fail '原配置记录与服务不匹配'
  # Only new operations need the new private file; rollback must remain independent of it.
  poll_recovery_env_fields
  case "$poll_project" in ''|*[!a-z0-9_-]*) poll_fail '原项目名无效' ;; esac
  case "$poll_old_commit" in "$official_marker"|0184257-gpt-monitor|0184257-gpt-monitor-v2|0184257-gpt-monitor-poll|0184257-gpt-monitor-patch|0184257-intelligence-v2|0184257-intelligence-recovery-v1) ;; *) poll_fail '原版本记录不受支持' ;; esac
  poll_validate_image
  poll_count=0
  poll_first=''
  while IFS= read -r poll_file <&3 || [ -n "$poll_file" ]; do
    case "$poll_file" in /*) ;; *) poll_fail '原配置路径必须是绝对路径' ;; esac
    poll_no_symlinks "$poll_file"
    [ -f "$poll_file" ] || poll_fail '升级前的 Compose 文件已丢失'
    [ "$poll_count" -ne 0 ] || poll_first=$poll_file
    poll_count=$((poll_count + 1))
  done
  exec 3<&-
  [ "$poll_count" -gt 0 ] && [ "$poll_first" = "$poll_base" ] || poll_fail '原记录中的主 Compose 文件不匹配'
  poll_image_record_text | cmp -s - "$poll_previous_image" || poll_fail '原镜像记录被修改'
  sha256sum -c "$poll_previous_hashes" || poll_fail '升级前的配置或程序被修改，请先核对记录'
}
poll_choose_binary() {
  poll_platform=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$poll_image") || poll_fail '读取镜像架构失败'
  case "$poll_platform" in
    linux/amd64) poll_binary="$poll_bundle/bin/linux-amd64/sub2api" ;;
    linux/arm64) poll_binary="$poll_bundle/bin/linux-arm64/sub2api" ;;
    *) poll_fail '仅支持 Linux amd64 和 arm64 镜像' ;;
  esac
}
poll_overlay_text() {
  poll_yaml_binary=$(printf '%s' "$poll_binary" | sed "s/'/''/g" | sed 's/\$/$$/g')
  cat <<EOF
# Generated by the 0.2.16 patch updater. Keep the package and previous records.
services:
  '$poll_service':
    image: '$poll_image'
    pull_policy: never
    volumes:
      - type: bind
        source: '$poll_yaml_binary'
        target: /app/sub2api
        read_only: true
        bind:
          create_host_path: false
EOF
  if [ -n "$poll_recovery_env_file" ]; then
    poll_yaml_env_file=$(printf '%s' "$poll_recovery_env_file" | sed "s/'/''/g" | sed 's/\$/$$/g')
    cat <<EOF
    env_file:
      - path: '$poll_yaml_env_file'
        format: raw
        required: true
EOF
  fi
}
poll_validate_overlay() {
  poll_no_symlinks "$poll_overlay"
  [ -f "$poll_overlay" ] || poll_fail '找不到新版 Compose 覆盖文件'
  poll_validate_recovery_env
  poll_choose_binary
  poll_overlay_text | cmp -s - "$poll_overlay" || poll_fail '新版覆盖文件已被修改或包目录被移动'
}
poll_compose() {
  poll_mode=$1
  poll_action=$2
  set -- --project-directory "$poll_dir" -p "$poll_project"
  poll_line=0
  while IFS= read -r poll_file || [ -n "$poll_file" ]; do
    poll_line=$((poll_line + 1))
    [ "$poll_line" -gt 7 ] || continue
    set -- "$@" -f "$poll_file"
  done < "$poll_previous" || return 1
  [ "$poll_line" -gt 7 ] || return 1
  if [ "$poll_mode" = new ]; then
    set -- "$@" -f "$poll_overlay"
  else
    set -- "$@" -f "$poll_previous_image"
  fi
  case "$poll_action" in
    config) docker compose "$@" config --quiet ;;
    version) docker compose "$@" exec -T "$poll_service" /app/sub2api --version ;;
    up) docker compose "$@" up -d --no-deps --force-recreate --pull never --no-build --wait --wait-timeout 180 "$poll_service" ;;
    logs) docker compose "$@" logs --tail=100 "$poll_service" ;;
    *) poll_fail '管理动作无效' ;;
  esac
}
