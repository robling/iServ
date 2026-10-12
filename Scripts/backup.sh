#!/bin/bash
# iServ 备份脚本：导出数据库 + 打包 Config/ Data/
# 用法: sudo iserv-backup [label]   例如 sudo iserv-backup pre-upgrade
set -euo pipefail

BASE=${ISERV_BASE:-/home/lighthouse}
ENV_FILE=${ISERV_ENV:-/etc/iserv/backup.env}
BACKUP_DIR="$BASE/Backup"
KEEP_MONTHLY=6
KEEP_MANUAL=5
MIN_DUMP_BYTES=10240

log() { echo "iserv-backup: $*"; logger -t iserv-backup -- "$*" 2>/dev/null || true; }
die() { echo "iserv-backup: ERROR: $*" >&2; logger -p user.err -t iserv-backup -- "ERROR: $*" 2>/dev/null || true; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root"
LABEL=${1:-}
if [ -n "$LABEL" ] && ! [[ "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then die "invalid label: $LABEL"; fi
[ -r "$ENV_FILE" ] || die "missing $ENV_FILE"
# shellcheck disable=SC1090
. "$ENV_FILE"
: "${DB_USER:?DB_USER not set}" "${DB_PASSWORD:?DB_PASSWORD not set}"
DB_NAME=${DB_NAME:-blog}; DB_CONTAINER=${DB_CONTAINER:-db}

TS=$(date +%Y%m%d_%H%M%S)
NAME="backup_${TS}${LABEL:+_$LABEL}.tar.gz"
mkdir -p "$BACKUP_DIR"
TMP_DUMP="$BASE/Data/.dump.sql.tmp"
TMP_TAR="$BACKUP_DIR/.${NAME}.tmp"
trap 'rm -f "$TMP_DUMP" "$TMP_TAR"' EXIT

log "start $NAME"
# 注：不加 --routines（WordPress 不用存储过程；且 MariaDB 自动升级后若未跑 mariadb-upgrade，mysql.proc 不兼容会报错）
# 密码经 stdin 传入容器，不出现在进程参数中
printf '%s' "$DB_PASSWORD" | podman exec -i "$DB_CONTAINER" sh -c \
  'MYSQL_PWD="$(cat)" exec mariadb-dump --single-transaction --triggers -u "$1" "$2"' \
  _ "$DB_USER" "$DB_NAME" > "$TMP_DUMP" || die "mariadb-dump failed"
SIZE=$(stat -c %s "$TMP_DUMP")
[ "$SIZE" -ge "$MIN_DUMP_BYTES" ] || die "dump too small ($SIZE bytes)"
tail -c 200 "$TMP_DUMP" | grep -q "Dump completed" || die "dump incomplete"
mv -f "$TMP_DUMP" "$BASE/Data/dump.sql"
log "dump ok ($SIZE bytes)"

tar -C "$BASE" -cpzf "$TMP_TAR" Config/ Data/ || die "tar failed"
gzip -t "$TMP_TAR" || die "archive corrupt"
chmod 600 "$TMP_TAR"
mv -f "$TMP_TAR" "$BACKUP_DIR/$NAME"
# 兼容 README 的 scp 恢复方式
cp -f "$BACKUP_DIR/$NAME" "$BASE/.backup.tar.gz.tmp" && mv -f "$BASE/.backup.tar.gz.tmp" "$BASE/backup.tar.gz"
log "archive ok $BACKUP_DIR/$NAME ($(du -h "$BACKUP_DIR/$NAME" | cut -f1))"

# 保留策略：无标签(月度) 6 份，有标签(手动) 5 份
cd "$BACKUP_DIR"
ls -1 backup_*.tar.gz 2>/dev/null | grep -E '^backup_[0-9]{8}_[0-9]{6}\.tar\.gz$' | sort -r | tail -n +$((KEEP_MONTHLY+1)) | xargs -r rm -f --
ls -1 backup_*.tar.gz 2>/dev/null | grep -E '^backup_[0-9]{8}_[0-9]{6}_.+\.tar\.gz$' | sort -r | tail -n +$((KEEP_MANUAL+1)) | xargs -r rm -f --
log "done"
