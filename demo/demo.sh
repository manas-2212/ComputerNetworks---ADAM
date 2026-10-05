#!/usr/bin/env bash
# demo.sh — types each command at human speed, then RUNS it for real.
# Nothing is faked: every output on screen comes from the actual command.
# Usage:  ./demo/demo.sh <scene>      (see list at bottom)
# Record with Cmd+Shift+5 (Screen Recording). Terminal: dark theme, font 20-22pt.

PROMPT="$(whoami)@$(hostname -s) ~ % "

type_cmd() {                      # type_cmd "text" -> typed char by char
  printf '%s' "$PROMPT"
  local s="$1" i c
  for ((i=0; i<${#s}; i++)); do
    c="${s:i:1}"; printf '%s' "$c"
    sleep "0.0$((RANDOM%7+3))"
    [[ "$c" == " " ]] && sleep "0.0$((RANDOM%5))"
  done
  sleep "0.$((RANDOM%4+4))"; printf '\n'
}
run() { type_cmd "$1"; eval "$1"; sleep "${2:-2.5}"; }   # run "cmd" [pause-after]

scene2()  { clear; run "ifconfig en0"
            run "ping -c 3 10.7.21.52"; run "ping -c 3 10.7.24.127"; run "ping -c 3 10.7.13.20"; }
scene3()  { clear; run "sudo brew services list | grep dnsmasq"
            run 'grep -nE "address=|listen-address|bind-interfaces" /opt/homebrew/etc/dnsmasq.conf | head -4' 4
            run "dig +short app.team1.test"; run "dig +short api.team1.test"; run "dig app.team1.test" 5; }
scene4()  { clear   # run on Anant's Mac (edge)
            run "sed -n '/upstream backend_servers/,/^ *}/p' /opt/homebrew/etc/nginx/nginx.conf" 4
            run "grep -nE 'listen 443|server_name app|proxy_pass' /opt/homebrew/etc/nginx/nginx.conf" 4
            run "sudo nginx -t" 4; }
scene5()  { clear; run "curl -v https://app.team1.test/" 6; }
scene6a() { clear   # run on Akhil's Mac (or any client)
            run "curl http://10.7.24.127:3001/"; run "curl http://10.7.24.127:3001/api/status"; }
scene7a() { clear   # run on Darain's Mac (or any client)
            run "curl http://10.7.13.20:3002/"; run "curl http://10.7.13.20:3002/api/status"; }
scene67b(){ run 'curl -sk -D - https://app.team1.test/ -o /dev/null | grep X-Backend'; }
scene8()  { clear; type_cmd 'for i in {1..6}; do'
            printf '> '; type_cmd '  curl -sk -D - https://app.team1.test/ -o /dev/null | grep X-Backend' | sed 's/^[^>]*% //'
            printf '> done\n'
            for i in {1..6}; do curl -sk -D - https://app.team1.test/ -o /dev/null | grep X-Backend; sleep 0.6; done; sleep 3; }
scene9()  { clear; run "curl -I https://app.team1.test/api/status" 5; }
scene11() { clear; run "curl -sk https://app.team1.test/" 3
            run 'curl -sk -D - https://app.team1.test/api/status -o /dev/null | grep -E "HTTP|X-Backend"' 5; }

# ---- Failure demonstrations (Section 5 / D3) — run on a client Mac ----
f1() { clear   # wrong DNS server: public resolver has no record for the private name
       run "dig +short app.team1.test @10.7.17.68" 2
       run "dig app.team1.test @8.8.8.8 | grep -E 'status|SERVER'" 4; }
f2() { clear   # Backend A stopped (Akhil presses Ctrl+C first): every request lands on B
       type_cmd 'for i in {1..4}; do curl -sk -D - https://app.team1.test/ -o /dev/null | grep X-Backend; done'
       for i in {1..4}; do curl -sk -D - https://app.team1.test/ -o /dev/null | grep X-Backend; sleep 0.6; done
       sleep 3; }
f3() { clear   # both backends stopped: edge still answers TLS, but has no upstream
       run "curl -sk -i https://app.team1.test/ | head -n 1" 4; }
f4() { clear   # wrong destination port: DNS fine, nothing listening on 8443
       run "curl -sS --connect-timeout 3 https://app.team1.test:8443/" 4; }

case "$1" in
  2|3|4|5|8|9|11) "scene$1";;
  6a|7a) "scene$1";;
  6b|7b) scene67b;;
  f1|f2|f3|f4) "$1";;
  *) echo "scenes: 2 3 4 5 6a 6b 7a 7b 8 9 11   failures: f1 f2 f3 f4"; exit 1;;
esac
