#!/bin/sh
# Update an existing 0.2.16 monitor patch without replacing its mounted binary.
set -eu
set -f

fail() { printf '更新失败：%s\n' "$*" >&2; exit 1; }
[ "$#" -le 2 ] || fail '用法：sh gpt-monitor-patch-0.2.16-v2/update.sh [docker-compose.yml] [sub2api]'
compose_file=docker-compose.yml
service=sub2api
if [ "$#" -ge 1 ]; then compose_file=$1; fi
if [ "$#" -ge 2 ]; then service=$2; fi
case "$service" in ''|*[!a-zA-Z0-9_.-]*) fail '服务名无效' ;; esac

# Check every component, including the script path, before resolving physical
# directories. A symlink must not turn the new package into the old package.
no_symlinks() {
  checked_path=$1
  case "$checked_path" in /*) ;; *) checked_path="$(pwd -P)/$checked_path" ;; esac
  while [ "$checked_path" != / ]; do
    [ ! -L "$checked_path" ] || fail '部署文件和程序路径不能包含符号链接'
    checked_path=$(dirname -- "$checked_path")
  done
}
case "$compose_file$0" in *'
'*) fail '路径不能包含换行符' ;; esac
no_symlinks "$compose_file"
no_symlinks "$0"
[ -f "$compose_file" ] || fail '找不到原 Compose 文件；请在原部署目录执行'
compose_dir=$(CDPATH= cd -- "$(dirname -- "$compose_file")" && pwd -P)
[ "$(pwd -P)" = "$compose_dir" ] || fail '请先进入原 Compose 文件所在目录'
compose_file="$compose_dir/$(basename -- "$compose_file")"
bundle_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
case "$bundle_dir$compose_file" in *'
'*) fail '路径不能包含换行符' ;; esac
[ "$(basename -- "$bundle_dir")" = gpt-monitor-patch-0.2.16-v2 ] || fail '请将新版解压到独立的 gpt-monitor-patch-0.2.16-v2 目录，不要覆盖旧包'
old_override="$compose_dir/docker-compose.gpt-monitor.yml"
rollback_file="$compose_dir/docker-compose.gpt-monitor.rollback-0.2.16.yml"
override_file="$compose_dir/docker-compose.gpt-monitor-v2.yml"
for required in "$old_override" "$rollback_file" "$bundle_dir/SHA256SUMS" "$bundle_dir/UPSTREAM_BASE.txt"; do
  no_symlinks "$required"
  [ -f "$required" ] || fail '缺少旧巡检覆盖文件、官方回滚记录或新版校验文件；未修改部署'
done
[ ! -e "$override_file" ] && [ ! -L "$override_file" ] || fail 'docker-compose.gpt-monitor-v2.yml 已存在；不会覆盖，请先检查现有部署'
for command_name in sha256sum awk sed od tr cmp cut docker; do
  command -v "$command_name" >/dev/null 2>&1 || fail "系统缺少 $command_name"
done

# Require a safe, complete checksum list before opening any listed file. The
# list is an integrity check, not a signature; obtain the package from its author.
awk '
  length($1) != 64 || $1 ~ /[^0-9a-f]/ || substr($0,65,2) != "  " { exit 1 }
  {
    name=substr($0,67)
    if (name !~ /^[a-zA-Z0-9_.\/-]+$/ || name ~ /^\// || name ~ /(^|\/)\.\.?(\/|$)/ || seen[name]++) exit 1
  }
  END { if (!seen["update.sh"] || !seen["UPSTREAM_BASE.txt"] || !seen["bin/linux-amd64/sub2api"] || !seen["bin/linux-arm64/sub2api"]) exit 1 }
' "$bundle_dir/SHA256SUMS" || fail 'SHA256SUMS 格式无效或未覆盖关键文件'
while IFS= read -r checksum_line || [ -n "$checksum_line" ]; do
  checksum_path=$(printf '%s' "$checksum_line" | cut -c 67-)
  no_symlinks "$bundle_dir/$checksum_path"
  [ -f "$bundle_dir/$checksum_path" ] || fail '校验清单中的文件缺失'
done < "$bundle_dir/SHA256SUMS"
(cd "$bundle_dir" && sha256sum -c SHA256SUMS) || fail '文件校验失败，请重新获取完整安装包'
printf '%s\n' '01842576b3d5c1e2545b5a99ad555d36e28ed306' | cmp -s - "$bundle_dir/UPSTREAM_BASE.txt" || fail '新版安装包构建基线不符'
for architecture in amd64 arm64; do
  candidate="$bundle_dir/bin/linux-$architecture/sub2api"
  no_symlinks "$candidate"
  [ -f "$candidate" ] && [ -x "$candidate" ] || fail '程序缺少执行权限；请在 Linux 上用 tar 重新解压'
  magic=$(od -An -tx1 -N7 "$candidate" | tr -d ' \n')
  kind=$(od -An -tx1 -j16 -N2 "$candidate" | tr -d ' \n')
  machine=$(od -An -tx1 -j18 -N2 "$candidate" | tr -d ' \n')
  [ "$magic" = 7f454c46020101 ] || fail '程序不是受支持的 64 位小端 ELF 文件'
  case "$kind" in 0200|0300) ;; *) fail 'ELF 程序类型无效' ;; esac
  case "$architecture:$machine" in amd64:3e00|arm64:b700) ;; *) fail 'ELF 程序架构与目录不符' ;; esac
done

docker compose version >/dev/null 2>&1 || fail '需要 Docker Compose v2'
up_help=$(docker compose up --help) || fail '无法检查 Compose 启动选项'
case "$up_help" in *--wait-timeout*) ;; *) fail '需要支持 --wait 和 --wait-timeout 的 Docker Compose' ;; esac
old_compose() { docker compose -f "$compose_file" -f "$old_override" "$@"; }
new_compose() { docker compose -f "$compose_file" -f "$override_file" "$@"; }
container_id=$(old_compose ps -q "$service") || fail '读取现有 Compose 服务失败'
case "$container_id" in ''|*[!0-9a-f]*) fail '必须有且只有一个正在运行的指定服务；多副本请手动操作' ;; esac
current_version=$(old_compose exec -T "$service" /app/sub2api --version 2>&1) || fail '无法读取当前程序版本；未修改容器'
version=$(printf '%s\n' "$current_version" | awk '/Sub2API / { for (i=1;i<NF;i++) if ($i=="Sub2API") { print $(i+1); exit } }')
commit=$(printf '%s\n' "$current_version" | awk '/Sub2API / { for (i=1;i<=NF;i++) if ($i=="Sub2API") { if (i+3<=NF && $(i+2)=="(commit:") { value=$(i+3); sub(/,$/,"",value); print value } exit } }')
[ "$version" = 0.2.16 ] || fail '仅支持当前运行版本 0.2.16；未修改容器'
[ "$commit" != 0184257-gpt-monitor-v2 ] || fail '当前已经运行此新版，无需重复更新'
[ "$commit" = 0184257-gpt-monitor ] || fail '当前构建标记不符：仅支持从 0184257-gpt-monitor 更新'
image_id=$(docker inspect --format '{{.Image}}' "$container_id") || fail '读取当前镜像失败'
image_hash=${image_id#sha256:}
[ "$image_id" != "$image_hash" ] && [ "${#image_hash}" -eq 64 ] || fail '无法确认当前容器的完整镜像 ID'
case "$image_hash" in *[!0-9a-f]*) fail '无法确认当前容器的完整镜像 ID' ;; esac
# Verify the existing official rollback record exactly; never rewrite it.
cat <<EOF | cmp -s - "$rollback_file" || fail '官方 0.2.16 回滚记录与当前镜像或服务不符；未修改容器'
# Official Sub2API 0.2.16, commit 01842576b3d5c1e2545b5a99ad555d36e28ed306.
# Generated by gpt-monitor-patch-0.2.16/apply.sh. Keep for rollback.
services:
  '$service':
    image: '$image_id'
    pull_policy: never
EOF
platform=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image_id") || fail '读取当前镜像架构失败'
case "$platform" in
  linux/amd64) binary="$bundle_dir/bin/linux-amd64/sub2api" ;;
  linux/arm64) binary="$bundle_dir/bin/linux-arm64/sub2api" ;;
  *) fail '仅支持 Linux amd64 和 arm64 镜像' ;;
esac
mounted_binary=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/app/sub2api"}}{{.Source}}{{println}}{{end}}{{end}}' "$container_id") || fail '读取当前程序挂载源失败'
case "$mounted_binary" in
  ''|*'
'*) fail '当前程序挂载源不明确；未修改容器' ;;
  /*) ;;
  *) fail '当前程序挂载源必须为本机绝对路径' ;;
esac
no_symlinks "$mounted_binary"
[ -f "$mounted_binary" ] || fail '当前程序挂载源不在本机；请按实际 Docker 环境手动更新'
case "$mounted_binary" in "$bundle_dir"/*) fail '新版目录已经被当前容器挂载；请使用独立目录' ;; esac
[ ! "$binary" -ef "$mounted_binary" ] || fail '新版程序与旧挂载程序是同一个文件；请重新独立解压'
old_compose config --quiet || fail '原巡检 Compose 配置检查失败；未修改部署'
docker compose -f "$compose_file" -f "$rollback_file" config --quiet || fail '官方回滚 Compose 配置检查失败；未修改部署'

# This is the first write. Preserve both old configuration files and the old
# binary so operators can restore the preceding patch or the official build.
yaml_binary=$(printf '%s' "$binary" | sed "s/'/''/g" | sed 's/\$/$$/g')
(
  umask 077
  set -C
  cat > "$override_file" <<EOF
# Generated by gpt-monitor-patch-0.2.16-v2/update.sh. Keep both package directories.
services:
  '$service':
    image: '$image_id'
    pull_policy: never
    volumes:
      - type: bind
        source: '$yaml_binary'
        target: /app/sub2api
        read_only: true
        bind:
          create_host_path: false
EOF
) || fail '创建新版覆盖文件失败；未修改容器'
new_compose config --quiet || fail '新版 Compose 配置检查失败；保留 v2 文件供检查，未重建容器'
new_compose up -d --no-deps --force-recreate --pull never --no-build --wait --wait-timeout 180 "$service" || fail '新版服务启动或健康检查失败；可使用原巡检覆盖文件恢复旧补丁，或 rollback.sh 恢复官方 0.2.16'
installed_version=$(new_compose exec -T "$service" /app/sub2api --version 2>&1) || fail '无法核验新版；请检查容器日志或使用原覆盖文件恢复'
case "$installed_version" in
  *'Sub2API 0.2.16 (commit: 0184257-gpt-monitor-v2,'*) ;;
  *) fail '服务已重建，但新版构建标记不符；请检查日志或使用原覆盖文件恢复' ;;
esac
printf '\n更新完成：Sub2API 0.2.16，构建标记 0184257-gpt-monitor-v2。\n'
printf '后续启动使用原 Compose 文件和 docker-compose.gpt-monitor-v2.yml；请保留新旧两个安装包目录。\n'
printf '旧巡检覆盖文件及官方回滚记录均已保留：原覆盖文件可恢复旧补丁，rollback.sh 可恢复官方 0.2.16。\n'
