#!/usr/bin/env bash
# uji 3 algoritma LB dari WSL ke VPS (RR, LC, IP Hash)
# pakai (di folder proyek): ./loadtest/run-lb-test.sh IP-PUBLIK
IP=${1:?pakai: ./loadtest/run-lb-test.sh IP-PUBLIK}
KEY=${KEY:-$HOME/.ssh/oci_capstone}
APP_DIR=/var/www/capstone
SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new ubuntu@$IP"
OUT=results
mkdir -p "$OUT"
: > "$OUT/summary.txt"

lat()  { grep -m1 "Time per request" "$1" | awk '{print $4}'; }
rps()  { grep -m1 "Requests per second" "$1" | awk '{print $4}'; }
bad()  { grep -m1 "Non-2xx" "$1" | awk '{print $3}'; }

for algo in rr lc iphash; do
  echo "=== $algo ==="
  $SSH "cd $APP_DIR && ./switch-lb.sh $algo" > /dev/null
  sleep 5
  START=$($SSH "date -u +%Y-%m-%dT%H:%M:%SZ")
  T0=$(date +%s)

  # 1) GET saja, 2) POST saja, 3) campuran GET + POST bersamaan
  ab -q -l -n 1000 -c 50 "http://$IP/api/campaigns" > "$OUT/$algo-get.txt"
  ab -q -l -n 1000 -c 50 -p loadtest/post.json -T application/json "http://$IP/api/donations" > "$OUT/$algo-post.txt"
  ab -q -l -n 1000 -c 25 "http://$IP/api/campaigns" > "$OUT/$algo-mix-get.txt" &
  ab -q -l -n 1000 -c 25 -p loadtest/post.json -T application/json "http://$IP/api/donations" > "$OUT/$algo-mix-post.txt" &
  wait

  DUR=$(( $(date +%s) - T0 + 10 ))
  $SSH "cd $APP_DIR && ./loadtest/server-report.sh $START $DUR" > "$OUT/$algo-server.txt"
  $SSH "cd $APP_DIR && docker compose logs nginx --tail=20 --no-log-prefix" > "$OUT/$algo-nginx-log.txt"

  {
    echo "[$algo]"
    echo "  GET   : latensi=$(lat $OUT/$algo-get.txt) ms, rps=$(rps $OUT/$algo-get.txt), non2xx=$(bad $OUT/$algo-get.txt)"
    echo "  POST  : latensi=$(lat $OUT/$algo-post.txt) ms, rps=$(rps $OUT/$algo-post.txt), non2xx=$(bad $OUT/$algo-post.txt)"
    echo "  Mix   : GET=$(lat $OUT/$algo-mix-get.txt) ms, POST=$(lat $OUT/$algo-mix-post.txt) ms"
    sed 's/^/  /' "$OUT/$algo-server.txt"
  } | tee -a "$OUT/summary.txt"
done

echo
echo "Selesai. Ringkasan: $OUT/summary.txt, log Nginx per algoritma: $OUT/*-nginx-log.txt"
