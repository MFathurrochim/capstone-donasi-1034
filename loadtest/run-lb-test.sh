#!/usr/bin/env bash
# uji 3 algoritma LB berulang (urutan dirotasi tiap ronde) dari WSL ke VPS
# pakai (di folder proyek): ./loadtest/run-lb-test.sh IP-PUBLIK [jumlah-ronde, default 3]
IP=${1:?pakai: ./loadtest/run-lb-test.sh IP-PUBLIK [ronde]}
ROUNDS=${2:-3}
KEY=${KEY:-$HOME/.ssh/oci_capstone}
APP_DIR=/var/www/capstone
SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new ubuntu@$IP"
OUT=results
mkdir -p "$OUT"
RAW="$OUT/raw.csv"
echo "round,algo,get_ms,post_ms,mixget_ms,mixpost_ms,app1,app2,cpu_peak,ram_peak" > "$RAW"

lat() { grep -m1 "Time per request" "$1" | awk '{print $4}'; }

# hapus donasi hasil uji beban supaya ukuran tabel sama di tiap percobaan
clean_db() {
  echo "DELETE FROM donations WHERE donor_name = 'Uji Beban';" |
    $SSH "cd $APP_DIR && docker compose exec -T db sh -c 'psql -q -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\"'" > /dev/null
}

ORDERS=("rr lc iphash" "lc iphash rr" "iphash rr lc")

for ((r=1; r<=ROUNDS; r++)); do
  order=${ORDERS[$(( (r-1) % 3 ))]}
  for algo in $order; do
    echo "=== ronde $r / $algo ==="
    clean_db
    $SSH "cd $APP_DIR && ./switch-lb.sh $algo" > /dev/null 2>&1
    sleep 5
    P="$OUT/r$r-$algo"
    START=$($SSH "date -u +%Y-%m-%dT%H:%M:%SZ")
    T0=$(date +%s)

    # 1) GET saja, 2) POST saja, 3) campuran GET + POST bersamaan
    ab -q -l -n 1000 -c 50 "http://$IP/api/campaigns" > "$P-get.txt"
    ab -q -l -n 1000 -c 50 -p loadtest/post.json -T application/json "http://$IP/api/donations" > "$P-post.txt"
    ab -q -l -n 1000 -c 25 "http://$IP/api/campaigns" > "$P-mix-get.txt" &
    ab -q -l -n 1000 -c 25 -p loadtest/post.json -T application/json "http://$IP/api/donations" > "$P-mix-post.txt" &
    wait

    DUR=$(( $(date +%s) - T0 + 10 ))
    $SSH "cd $APP_DIR && ./loadtest/server-report.sh $START $DUR" > "$P-server.txt"
    $SSH "cd $APP_DIR && docker compose logs nginx --tail=20 --no-log-prefix" > "$P-nginx-log.txt"

    n1=$(sed -n 's/.*app1=\([0-9]*\).*/\1/p' "$P-server.txt")
    n2=$(sed -n 's/.*app2=\([0-9]*\).*/\1/p' "$P-server.txt")
    cpu=$(sed -n 's/.*cpu_peak=\([^% ]*\)%.*/\1/p' "$P-server.txt")
    ram=$(sed -n 's/.*ram_peak=\([^% ]*\)%.*/\1/p' "$P-server.txt")
    echo "$r,$algo,$(lat $P-get.txt),$(lat $P-post.txt),$(lat $P-mix-get.txt),$(lat $P-mix-post.txt),${n1:-0},${n2:-0},${cpu:-0},${ram:-0}" | tee -a "$RAW"
  done
done
clean_db

{
  echo "RINGKASAN ($ROUNDS ronde, rata-rata)"
  for a in rr lc iphash; do
    awk -F, -v a="$a" '$2==a {n++; g+=$3; p+=$4; mg+=$5; mp+=$6; s1+=$7; s2+=$8; c+=$9; m+=$10}
      END {if (n) {t=s1+s2; printf "%-7s GET=%.1f ms  POST=%.1f ms  Mix(GET/POST)=%.1f/%.1f ms  dist=%.1f%%:%.1f%%  CPU=%.1f%%  RAM=%.1f%%\n", a, g/n, p/n, mg/n, mp/n, (t ? s1*100/t : 0), (t ? s2*100/t : 0), c/n, m/n}}' "$RAW"
  done
} | tee "$OUT/summary.txt"
echo "Data mentah per ronde: $RAW | log Nginx: $OUT/r*-nginx-log.txt"
