#!/usr/bin/env bash
# Cloud Operations Lab - reproducible incident drills.
#
# Usage:
#   chaos/lab.sh up                 start the healthy baseline
#   chaos/lab.sh verify             check every operational signal
#   chaos/lab.sh break  <id>        inject the failure for incident <id>
#   chaos/lab.sh detect <id>        confirm the failure signal is present
#   chaos/lab.sh fix    <id>        apply the documented resolution
#   chaos/lab.sh drill  <id>        baseline -> break -> detect -> fix -> verify
#   chaos/lab.sh list               list available incidents
#
# Incident ids: 01 .. 09 (see incidents/).

set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash on Windows: keep /tmp and /etc paths as-is

cd "$(dirname "$0")/.."

C=cloud-operations-lab
URL=http://127.0.0.1:8080/health
OVR=chaos/overrides

log()  { printf '\033[36m[lab]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[ ok ]\033[0m %s\n' "$*"; }
bad()  { printf '\033[31m[FAIL]\033[0m %s\n' "$*"; }

compose() { docker compose "$@"; }

up_with() { # up_with [override.yml]
  local files=(-f docker-compose.yml) out
  [ $# -gt 0 ] && files+=(-f "$OVR/$1")
  out=$(compose "${files[@]}" up -d --build --force-recreate 2>&1) || { echo "$out"; return 1; }
}

in_c() { docker exec "$C" "$@"; }

host_health() { curl -fsS -m 3 "$URL" >/dev/null 2>&1; }
inner_health() { in_c python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2)" >/dev/null 2>&1; }
health_status() { docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$C" 2>/dev/null || echo missing; }
restarts() { docker inspect -f '{{.RestartCount}}' "$C" 2>/dev/null || echo 0; }
cpu_pct() { docker stats --no-stream --format '{{.CPUPerc}}' "$C" | tr -d '%' | cut -d. -f1; }
mem_mib() { in_c python -c "print(int(open('/sys/fs/cgroup/memory.current').read())//1048576)"; }
log_mib() { in_c sh -c "du -sm /var/log | cut -f1"; }
dns_ok() { in_c python -c "import socket;socket.gethostbyname('example.com')" >/dev/null 2>&1; }
bind_addr() { docker port "$C" 8080/tcp | head -1 | cut -d: -f1; }

wait_for() { # wait_for <seconds> <command...>
  local t=$1; shift
  for _ in $(seq "$t"); do "$@" && return 0; sleep 1; done
  return 1
}

# ---------------------------------------------------------------- baseline

cmd_up() {
  log "starting healthy baseline"
  up_with
  wait_for 60 host_health || { bad "baseline did not become reachable"; docker logs "$C" | tail -20; exit 1; }
  wait_for 60 sh -c "[ \"\$(docker inspect -f '{{.State.Health.Status}}' $C)\" = healthy ]" \
    || { bad "baseline did not become healthy"; exit 1; }
  ok "baseline healthy"
}

cmd_verify() {
  local rc=0
  host_health                      && ok "host -> /health reachable"        || { bad "host cannot reach /health"; rc=1; }
  [ "$(health_status)" = healthy ] && ok "docker health: healthy"          || { bad "docker health: $(health_status)"; rc=1; }
  [ "$(bind_addr)" = 127.0.0.1 ]   && ok "published on 127.0.0.1 only"     || { bad "published on $(bind_addr)"; rc=1; }
  [ "$(cpu_pct)" -lt 50 ]          && ok "cpu below 50%"                   || { bad "cpu $(cpu_pct)%"; rc=1; }
  [ "$(mem_mib)" -lt 150 ]         && ok "memory below 150 MiB"            || { bad "memory $(mem_mib) MiB"; rc=1; }
  [ "$(log_mib)" -lt 50 ]          && ok "/var/log below 50 MiB"           || { bad "/var/log $(log_mib) MiB"; rc=1; }
  dns_ok                           && ok "dns resolves example.com"        || { bad "dns resolution failing"; rc=1; }
  return $rc
}

# ---------------------------------------------------------------- incidents

break_01() { up_with 01-wrong-port.yml; }
detect_01() { wait_for 20 inner_health && ! host_health; }
fix_01() { cmd_up; }

break_02() { up_with 02-healthcheck-wrong-port.yml; }
detect_02() { wait_for 60 sh -c "[ \"\$(docker inspect -f '{{.State.Health.Status}}' $C)\" = unhealthy ]" && inner_health; }
fix_02() { cmd_up; }

break_03() { up_with 03-missing-entrypoint.yml; }
detect_03() { wait_for 60 sh -c "[ \$(docker inspect -f '{{.RestartCount}}' $C) -ge 2 ]" && docker logs "$C" 2>&1 | grep -q "missing.py"; }
fix_03() { cmd_up; }

break_04() {
  docker exec -d "$C" python -c "import os;open('/tmp/cpu-stress.pid','w').write(str(os.getpid()))
while True: pass"
}
detect_04() { wait_for 20 sh -c "[ \$(docker stats --no-stream --format '{{.CPUPerc}}' $C | cut -d. -f1) -ge 50 ]" && host_health; }
fix_04() { in_c python -c "import os,signal;os.kill(int(open('/tmp/cpu-stress.pid').read()),signal.SIGTERM)"; in_c rm -f /tmp/cpu-stress.pid; }

break_05() {
  docker exec -d "$C" python -c "import os,time;open('/tmp/memory-stress.pid','w').write(str(os.getpid()));data=bytearray(180*1024*1024);time.sleep(3600)"
}
detect_05() { wait_for 20 sh -c "[ \$(docker exec $C python -c \"print(int(open('/sys/fs/cgroup/memory.current').read())//1048576)\") -ge 150 ]" && host_health; }
fix_05() { in_c python -c "import os,signal;os.kill(int(open('/tmp/memory-stress.pid').read()),signal.SIGTERM)"; in_c rm -f /tmp/memory-stress.pid; }

break_06() { in_c dd if=/dev/zero of=/var/log/cloud-operations-lab.log bs=1M count=64 status=none; }
detect_06() { [ "$(log_mib)" -ge 50 ] && host_health; }
fix_06() { in_c rm -f /var/log/cloud-operations-lab.log; }

break_07() {
  in_c sh -c "cp /etc/resolv.conf /tmp/resolv.conf.backup && printf 'nameserver 192.0.2.1\noptions timeout:1 attempts:1\n' > /etc/resolv.conf"
}
detect_07() {
  ! dns_ok && in_c python -c "import socket;socket.create_connection(('1.1.1.1',443),5).close()" && host_health
}
fix_07() { in_c sh -c "cat /tmp/resolv.conf.backup > /etc/resolv.conf && rm -f /tmp/resolv.conf.backup"; }

dep_tcp() { in_c python -c "import socket;socket.create_connection(('lab-dependency',9090),3).close()" >/dev/null 2>&1; }
break_08() {
  local img net
  img=$(docker inspect -f '{{.Config.Image}}' "$C")
  net=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$C")
  docker rm -f lab-dependency >/dev/null 2>&1 || true
  docker run -d --name lab-dependency --network "$net" "$img" \
    sh -c 'python -m http.server 9090 >/tmp/http.log 2>&1 & echo $! >/tmp/http.pid; tail -f /dev/null' >/dev/null
  wait_for 20 dep_tcp || { bad "dependency never started listening"; return 1; }
  docker exec lab-dependency sh -c 'kill $(cat /tmp/http.pid)'
}
detect_08() {
  in_c python -c "import socket;socket.gethostbyname('lab-dependency')" >/dev/null 2>&1 \
    && wait_for 10 sh -c "! docker exec $C python -c \"import socket;socket.create_connection(('lab-dependency',9090),3).close()\" >/dev/null 2>&1" \
    && host_health
}
fix_08() {
  docker exec lab-dependency sh -c 'python -m http.server 9090 >/tmp/http.log 2>&1 & echo $! >/tmp/http.pid'
  wait_for 20 dep_tcp && ok "dependency listening again on :9090"
  docker rm -f lab-dependency >/dev/null
}

break_09() { up_with 09-exposed-all-interfaces.yml; }
detect_09() { wait_for 30 host_health && [ "$(bind_addr)" = 0.0.0.0 ]; }
fix_09() { cmd_up; }

# ---------------------------------------------------------------- dispatcher

titles() {
  cat <<'EOF'
01  Service unreachable - wrong Docker port mapping
02  Container health check failure
03  Application restart loop - missing entrypoint
04  High CPU usage
05  Memory pressure
06  Log growth and disk pressure
07  DNS resolution failure
08  Internal network connectivity failure
09  Service exposed on all network interfaces
EOF
}

need_id() {
  [ -n "${1:-}" ] && declare -F "break_$1" >/dev/null || { bad "unknown incident '${1:-}'"; titles; exit 2; }
}

cmd_drill() {
  local id=$1 t0 t1
  log "drill $id: $(titles | grep "^$id" | cut -c5-)"
  cmd_up
  log "injecting failure"
  "break_$id"
  t0=$(date +%s)
  if "detect_$id"; then ok "failure signal detected"; else bad "failure signal NOT detected"; exit 1; fi
  t1=$(date +%s)
  log "applying resolution"
  "fix_$id"
  if wait_for 60 cmd_verify >/dev/null 2>&1; then cmd_verify; ok "drill $id passed (detected in $((t1 - t0))s)"
  else cmd_verify || true; bad "drill $id did not recover"; exit 1; fi
}

case "${1:-}" in
  up)      cmd_up ;;
  verify)  cmd_verify ;;
  list)    titles ;;
  break)   need_id "${2:-}"; "break_$2";  log "incident $2 injected" ;;
  detect)  need_id "${2:-}"; if "detect_$2"; then ok "incident $2 signal present"; else bad "incident $2 signal absent"; exit 1; fi ;;
  fix)     need_id "${2:-}"; "fix_$2";    log "incident $2 resolution applied" ;;
  drill)   need_id "${2:-}"; cmd_drill "$2" ;;
  *)       sed -n '2,13p' "$0"; exit 2 ;;
esac
