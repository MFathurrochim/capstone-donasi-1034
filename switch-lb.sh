#!/usr/bin/env bash
# ganti algoritma LB: ./switch-lb.sh rr | lc | iphash
set -e
case "$1" in
  rr|lc|iphash) ;;
  *) echo "pakai: ./switch-lb.sh rr|lc|iphash"; exit 1 ;;
esac
cp "lb/nginx.$1.conf" nginx.conf
docker compose restart nginx
echo "LB aktif: $1"
grep -E "least_conn|ip_hash" nginx.conf || echo "(round robin, tanpa direktif)"
