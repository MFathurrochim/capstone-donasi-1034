#!/usr/bin/env bash
# dijalankan di server: distribusi request ke app1/app2 + puncak CPU/RAM host
# pakai: ./loadtest/server-report.sh <waktu-mulai-RFC3339> <durasi-detik>
cd "$(dirname "$0")/.."
START=$1
DUR=${2:-60}

ip_of() {
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$(docker compose ps -q "$1")"
}
A1="$(ip_of app1):3000"
A2="$(ip_of app2):3000"

LOG=$(docker compose logs nginx --since "$START" --no-log-prefix 2>/dev/null)
N1=$(echo "$LOG" | grep -cF "upstream=$A1")
N2=$(echo "$LOG" | grep -cF "upstream=$A2")
echo "$N1 $N2" | awk '{t=$1+$2; if (t==0) {print "dist=n/a"} else {printf "dist=%.1f%%:%.1f%% (app1=%d app2=%d)\n", $1*100/t, $2*100/t, $1, $2}}'

q() {
  curl -s -G http://127.0.0.1:9090/api/v1/query --data-urlencode "query=$1" |
    python3 -c 'import sys,json; r=json.load(sys.stdin)["data"]["result"]; print(round(float(r[0]["value"][1]),1) if r else "n/a")'
}
CPU=$(q "max_over_time((100 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[15s])) * 100)[${DUR}s:5s])")
RAM=$(q "max_over_time(((1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)[${DUR}s:5s])")
echo "cpu_peak=${CPU}% ram_peak=${RAM}%"
