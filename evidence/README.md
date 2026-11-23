# Evidence Directory — Master Index

All project screenshots and packet captures are organized into category subfolders as required by the course project rubric.

---

## 📁 Folder Structure & Evidence Map

### 1. `evidence/dns/` — DNS Resolution & Resilience (Phase 1 & Phase 2)
- `02-dnsmasq-running.png`: Primary dnsmasq running (Phase 1)
- `25-final-dns.png`: Initial DNS resolution proof (Phase 1)
- `29-anant-dns-resolution.jpeg`: Client resolution on LAN (Phase 1)
- **`backup-dns-failover.png`**: **(Phase 2, Ext A)** Primary DNS stopped on Mac 1; client resolves `app.team1.test` via Mac 4 Backup DNS.
- **`ttl-30s-countdown.png`**: **(Phase 2, Ext B)** `dig` output displaying the 30-second TTL countdown in the ANSWER section.
- **`ttl-cache-and-flush.png`**: **(Phase 2, Ext B)** Client returning old cached IP until flushed, then immediately discovering the new IP (`.99`).

### 2. `evidence/firewall/` — Service Isolation & Security (Phase 2, Ext C)
- **`pfctl-rules-active.png`**: Terminal on Mac 3 / Mac 4 showing `sudo pfctl -sr` with rules restricting ports 3001 & 3002 to Edge IP (`MAC2_IP`).
- **`backend-direct-access-blocked.png`**: Output of `./scripts/test-service-isolation.sh` showing direct port 3001 & 3002 connections **REFUSED / BLOCKED**, while Edge proxy HTTPS access returns **HTTP 200 OK**.

### 3. `evidence/failover/` — High-Availability Failover (Phase 2, Ext D)
- **`backend-a-down-failover-to-b.png`**: Output of `./scripts/test-ha-failover.sh` showing 100% of requests seamlessly served by Backend B (`X-Backend: B`) when Backend A was killed, with **zero HTTP 502 errors**.

### 4. `evidence/cutover/` — Controlled Edge Migration (Phase 2, Ext E)
- **`standby-edge-cutover-header.png`**: Output of `./scripts/test-edge-migration.sh` showing client requests served by the standby edge with header `X-Edge-Proxy: nginx-standby-mac3`.

### 5. `evidence/troubleshooting/` — Fault Isolation Challenge (Phase 2, Ext F)
- **`diagnose-stack-4layers.png`**: Full execution output of `./scripts/diagnose-stack.sh` systematically isolating a fault layer-by-layer (DNS $\rightarrow$ TCP $\rightarrow$ TLS $\rightarrow$ Upstream App).

---

## 6. Phase 1 Historical Evidence Folders
- `evidence/failures/`: Phase 1 deliberate failure demonstrations (wrong DNS, wrong IP, dead backend, wrong port).
- `evidence/https/`: Phase 1 TLS certificate trust, load balancing alternation, and HTTP caching/ETag.
- `evidence/network/`: Phase 1 IP address and LAN configuration proofs.
- `evidence/wireshark/`: Phase 1 packet captures of TCP 3-way handshake and encrypted TLS traffic.
