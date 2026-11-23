# Team Adam — Faculty Troubleshooting Challenge Guide (Extension F)

During the evaluation, the faculty will inject a fault into the running network. The team must identify the layer, isolate the fault, and fix or explain it.

---

## The 4-Layer Diagnostic Protocol

Always troubleshoot in strict bottom-up order out loud:
1. **Application (DNS)**: Did the name resolve to the right IP?
2. **Network & Transport (IP & TCP)**: Can we ping the host? Is the TCP port accepting connections?
3. **Session & Security (TLS)**: Does the SSL handshake complete? Is the certificate valid?
4. **Application & Upstream (HTTP & Proxy)**: Does the web server answer? Are backends reachable?

Run our automated diagnostic script:
```bash
./scripts/diagnose-stack.sh
```

---

## Quick Fault Matrix & Diagnosis

| Symptom | Diagnostic Command | Root Cause | Layer | Fix |
|---|---|---|---|---|
| `Could not resolve host: app.team1.test` | `dig app.team1.test` returns no IP | Wrong DNS IP in System Settings or `dnsmasq` stopped on Mac 1 | **Application (DNS)** | Check `scutil --dns`. Restart `dnsmasq` or switch to Backup DNS (`10.7.13.20`). |
| Resolves to wrong IP (e.g., `10.7.21.99`) | `dig +short app.team1.test` | Incorrect DNS entry in `dnsmasq.conf` | **Application (DNS)** | Fix `address=` in `dnsmasq.conf` and run `sudo killall -HUP dnsmasq`. |
| `curl: (7) Failed to connect to host port 443: Connection refused` | `nc -zvw 2 10.7.21.52 443` | NGINX is stopped on Mac 2 or not listening on 443 | **Transport (TCP)** | Run `sudo brew services start nginx` or check `nginx.conf` `listen 443 ssl`. |
| `curl: (60) SSL certificate problem: unable to get local issuer certificate` | `openssl s_client -connect app.team1.test:443` | Root CA / cert not trusted in macOS Keychain or expired | **Session (TLS)** | Add `app.team1.test.crt` to Keychain Access -> System -> Always Trust. |
| `HTTP 502 Bad Gateway` | `curl -sk -I https://app.team1.test/` | Both backends (Port 3001 & 3002) are down, or firewall is blocking NGINX | **Application (Upstream)** | Start backends (`./scripts/start-backend-a.sh`), or check `pfctl -sr` on backends to allow Mac 2 IP. |
| Client can curl backend directly on 3001/3002 | `curl http://10.7.24.127:3001/` succeeds | Firewall was flushed or not enabled | **Security / Isolation** | Run `sudo ./scripts/apply-firewall.sh` on Mac 3 and Mac 4. |
| Requests take 60s to failover | `curl -v https://app.team1.test/` | Missing `proxy_connect_timeout` or `proxy_next_upstream` in NGINX | **Application (Proxy)** | Update NGINX with `nginx-phase2.conf` settings. |
