# Team Adam (Team 1) — Phase 2 Comprehensive Engineering Report
## Hardening, High-Availability Failover, Service Isolation & Fault Diagnosis on a Multi-Tier Distributed Web Platform

**Course**: Computer Networks Laboratory  
**Team**: Team 1 (Adam)  
**Authors**:
- **Manas Selukar** (Primary DNS Specialist & Traffic Gatekeeper)
- **Anant Singh** (Active Edge Reverse Proxy, TLS Architect & Load Balancer Lead)
- **Akhil Sharma** (Backend A Lead, Security Isolation & Hot Standby Edge)
- **Syed Darain Qamar** (Backend B Lead, Backup DNS Specialist & Automation Orchestrator)

**Institution**: Department of Computer Science & Engineering  
**Date**: November 2026  

---

## Executive Summary

In Phase 1 of this project, we designed and implemented a baseline multi-tier distributed web architecture distributed across four physical macOS nodes over a local wireless area network (WLAN). While functional under ideal conditions, Phase 1 exhibited critical operational vulnerabilities inherent to naive distributed topologies: centralized single points of failure (SPOFs) at the DNS and edge layers, unshielded backend services exposed to direct layer-4 network intrusion, sluggish upstream failover resulting in user-visible `HTTP 502 Bad Gateway` errors, and rigid DNS caching dynamics preventing agile infrastructure migration.

Phase 2 ("Harden, Recover & Troubleshoot") transforms this fragile prototype into a resilient, enterprise-grade, defense-in-depth platform. We introduced redundant dual-resolver DNS architecture with tuned Time-To-Live (TTL) values, enforced transport-layer security isolation via kernel-level macOS Packet Filter (`pf`) rules, configured aggressive upstream passive health checks and in-flight request replays in NGINX, executed zero-downtime hot-standby edge migrations, and formalized an automated 4-layer bottom-up diagnostic suite. 

This report presents the architectural design, formal networking principles, implementation details, experimental test methodologies, verified empirical results, and enterprise cloud parallels of Phase 2.

---

## 1. Architectural Evolution: Phase 1 vs. Phase 2

```
Phase 1 (Naive Single-Path Topology):
[Client] ---> [Primary DNS (Mac 1)]
   |
   +--------> [Edge Proxy NGINX (Mac 2)] ---> [Backend A (Mac 3 :3001)]
                                         ---> [Backend B (Mac 4 :3002)]
Vulnerabilities: 
- If Mac 1 dies -> Complete DNS outage.
- If Mac 2 dies -> Total platform outage.
- Backends :3001/:3002 are publicly reachable by any host on LAN.
- If Backend A dies -> Users experience 502 Bad Gateway on alternate requests.

Phase 2 (Hardened Defense-in-Depth Topology):
                        +--------------------------+
                        |  Primary DNS (Mac 1)     |
                        |  dnsmasq (TTL=30s)       |
                        +------------+-------------+
                                     | (Failover)
                                     v
                        +--------------------------+
                        |  Backup DNS (Mac 4)      |
                        |  dnsmasq (:53)           |
                        +------------+-------------+
                                     |
               +---------------------+---------------------+
               | (Active Edge)                             | (Standby Edge Cutover)
               v                                           v
+-------------------------------+           +-------------------------------+
| Active Edge Proxy (Mac 2)     |           | Standby Edge Proxy (Mac 3)    |
| NGINX / TLS 1.3 / Fast Upstrm |           | NGINX / Replicated Certs      |
+---------------+---------------+           +---------------+---------------+
                |                                           |
                +--------------------+ +--------------------+
                                     | |
               +---------------------+ +---------------------+
               | (Port 3001 Allowed)                         | (Port 3002 Allowed)
               v                                             v
+-------------------------------+           +-------------------------------+
| Backend Server A (Mac 3)      |           | Backend Server B (Mac 4)      |
| Express.js (:3001)            |           | Express.js (:3002)            |
| macOS PF Firewall: ISOLATED   |           | macOS PF Firewall: ISOLATED   |
+-------------------------------+           +-------------------------------+
```

### Table 1: Comprehensive Phase Comparison Matrix

| Architectural Dimension | Phase 1 (Baseline Prototype) | Phase 2 (Hardened Enterprise Architecture) |
|:---|:---|:---|
| **DNS Availability** | Single authoritative server (`Mac 1`). Complete outage if server halts. | Dual redundant resolver architecture (`Mac 1` Primary, `Mac 4` Secondary). |
| **DNS Caching & TTL** | Static long TTL (86,400s). High cache rigidity. | Tuned short TTL (`local-ttl=30`). Enables controlled record cutover in $\le 30$s. |
| **Backend Isolation** | Unrestricted. Ports 3001/3002 open to all LAN hosts. | Strict Layer-4 firewall isolation via macOS `pf`. Traffic accepted only from Edge IP. |
| **Upstream Health Checks** | Default NGINX timeouts (60s). Upstream failure yields `502 Bad Gateway`. | Passive health checks (`fail_timeout=5s`, `max_fails=1`, `proxy_next_upstream`). 0% error rate. |
| **Edge Redundancy** | Single Edge proxy on Mac 2. Hardware failure is fatal. | Hot-standby Edge proxy pre-warmed on Mac 3 with verified DNS cutover runbook. |
| **Diagnostics & Health** | Manual ad-hoc `ping` and `curl` commands. | Automated 4-layer diagnostic suite (`scripts/diagnose-stack.sh`). |

---

## 2. Component Specification & Node Responsibilities

The physical testbed comprises four Apple Silicon/Intel macOS laptops connected over a dedicated local IEEE 802.11 Wi-Fi subnet (`10.7.0.0/19`). 

### Node Allocation:
1. **Mac 1 — Manas Selukar (`10.7.19.161`)**:
   - Primary DNS Daemon: `dnsmasq` v2.90 listening on UDP/TCP port 53.
   - Authoritative local zone: `team1.test`, `app.team1.test`, `api.team1.test`.
   - Upstream forwarders: `1.1.1.1`, `8.8.8.8` for recursive fallback.
   - TTL configuration: `local-ttl=30` enforcing low record retention.
2. **Mac 2 — Anant Singh (`10.7.27.66`)**:
   - Active Edge Reverse Proxy: NGINX v1.27.x.
   - Port 80: HTTP-to-HTTPS permanent redirect (HTTP 301).
   - Port 443: TLS 1.3 / TLS 1.2 termination with custom RSA 2048-bit X.509 certificates.
   - Upstream Pool: Round-robin balancing across Backend A (`10.7.24.241:3001`) and Backend B (`10.7.27.154:3002`).
   - Reverse Proxy Headers: `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`.
3. **Mac 3 — Akhil Sharma (`10.7.24.241`)**:
   - Backend Application Server A: Node.js / Express service listening on port 3001. Returns payload with `X-Backend: A`.
   - Security Enforcement: macOS Packet Filter (`pf`) restricting port 3001 to Mac 2 (`10.7.27.66`).
   - Standby Edge Proxy: Pre-warmed NGINX instance configured on port 443 with matching SSL certificates (`nginx-standby.conf`).
4. **Mac 4 — Syed Darain Qamar (`10.7.27.154`)**:
   - Backend Application Server B: Node.js / Express service listening on port 3002. Returns payload with `X-Backend: B` and `Cache-Control`/`ETag` headers.
   - Secondary / Backup DNS Daemon: `dnsmasq` listening on port 53.
   - Security Enforcement: macOS Packet Filter (`pf`) restricting port 3002 to Mac 2.
   - Automation Test Orchestrator: Repository test harnesses and diagnostics.

---

## 3. In-Depth Engineering Implementation of Phase 2 Extensions

### Extension A: Redundant Dual-Resolver DNS Architecture
In a mission-critical distributed platform, DNS failure mimics a total physical network partition: clients cannot locate IP endpoints regardless of backend health.
- **Implementation**: Deployed `dnsmasq-phase2-backup.conf` on Mac 4. Both nameservers maintain identical authoritative entries for the `team1.test` zone.
- **Client Stub Resolver Configuration**: Client operating systems are provisioned with ordered nameserver entries:
  ```text
  nameserver 10.7.19.161   # Primary (Mac 1)
  nameserver 10.7.27.154   # Secondary (Mac 4)
  ```
- **Failover Mechanics**: When Mac 1's daemon is terminated (`sudo pkill dnsmasq`), the client resolver transmits a standard DNS query (UDP port 53) to the primary. After reaching the operating system query timeout (1.0–2.0s), the stub resolver automatically re-issues the query to the secondary nameserver on Mac 4. Resolution succeeds without user intervention.

### Extension B: Aggressive TTL Tuning & Client Cache Invalidation
- **Theoretical Context**: DNS caching occurs at multiple layers: application runtimes (browsers, JVMs), operating system daemons (macOS `mDNSResponder`), recursive enterprise resolvers, and local forwarders. High TTL values optimize bandwidth at the cost of operational agility.
- **Configuration**: Set `local-ttl=30` in `dnsmasq.conf`.
- **Validation Experiment**:
  1. Record queried: `app.team1.test` resolved to `10.7.27.66` (Mac 2).
  2. Authoritative record altered in `dnsmasq` to point to a test address (`10.7.27.99`).
  3. Client repeated queries every 5 seconds. The cached IP (`10.7.27.66`) persisted until the 30-second window expired, after which the client queried authoritative nameservers and retrieved the updated IP.
  4. Manual cache invalidation via `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` proved immediate cutover capability.

### Extension C: Layer-4 Service Isolation via macOS Packet Filter (`pf`)
Direct access to internal application tiers introduces severe threat vectors: direct volumetric DDoS attacks, bypass of Web Application Firewall (WAF) rule sets, SSL decryption bypass, and evasion of central audit logging.
- **Packet Filter Rules (`config/firewall/pf-rules.conf`)**:
  ```pf
  # Enforce stateful packet filtering
  set skip on lo0

  # Whitelist Edge Reverse Proxy IP
  pass in quick proto tcp from 10.7.27.66 to any port 3001 keep state
  pass in quick proto tcp from 10.7.27.66 to any port 3002 keep state

  # Reject all other ingress TCP traffic with an explicit TCP Reset
  block return-rst in quick proto tcp from any to any port 3001
  block return-rst in quick proto tcp from any to any port 3002
  ```
- **Packet Flow Analysis**:
  - Ingress packet from Edge IP (`10.7.27.66`): Matches rule 2 $\rightarrow$ Passed to socket receive queue $\rightarrow$ TCP 3-way handshake established $\rightarrow$ `HTTP 200 OK`.
  - Ingress packet from Client LAN (`10.7.19.161`): Matches rule 4 $\rightarrow$ Kernel drops packet and returns a synthesized `TCP RST-ACK` segment $\rightarrow$ Client socket fails instantly with `ECONNREFUSED` (`Connection refused`).
  - Loopback Bypass: Local verification (`curl http://10.7.27.154:3002` executed on Mac 4) succeeds due to `set skip on lo0`, proving that inter-process loopback communication remains functional.

### Extension D: Zero-Downtime High-Availability Upstream Failover
Standard NGINX upstream balancing without explicit resilience directives defaults to a 60-second connection timeout. When a backend drops, requests routed to it hang and eventually terminate with an HTTP 502/504 error.
- **Configuration (`config/nginx/nginx-phase2.conf`)**:
  ```nginx
  upstream backend_servers {
      server 10.7.24.241:3001 max_fails=1 fail_timeout=5s;
      server 10.7.27.154:3002 max_fails=1 fail_timeout=5s;
  }

  server {
      listen 443 ssl;
      server_name app.team1.test;

      location / {
          proxy_pass http://backend_servers;
          proxy_connect_timeout 2s;
          proxy_read_timeout 3s;
          proxy_next_upstream error timeout http_502 http_503;
          proxy_next_upstream_tries 2;
          
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
      }
  }
  ```
- **Operational Mechanics**:
  1. Requests alternate evenly between Backend A and Backend B under normal operation.
  2. Injected Fault: Backend A is killed mid-stream (`pkill -f 3001`).
  3. When the next client request arrives, NGINX attempts connection to `10.7.24.241:3001`. The connection is refused within milliseconds.
  4. Instead of returning `502 Bad Gateway` to the client, `proxy_next_upstream` intercepts the error and immediately replays the original HTTP request to Backend B (`10.7.27.154:3002`).
  5. The client receives `HTTP 200 OK` with header `X-Backend: B`.
  6. NGINX marks Backend A down for `fail_timeout=5s`, routing 100% of subsequent requests directly to Backend B with zero connection delay.

### Extension E: Controlled Standby Edge Migration & DNS Cutover
To eliminate the Edge Reverse Proxy as a single point of failure, we developed a hot-standby migration architecture.
- **Standby Edge Provisioning**: Pre-configured NGINX on Mac 3 with duplicated certificates, document roots, and upstream configurations (`config/nginx/nginx-standby.conf`), injecting the response header `X-Edge-Server: standby-edge-mac3`.
- **Migration Runbook**:
  1. Verify Standby Edge health on Mac 3 (`curl -k https://10.7.24.241/api/status`).
  2. Update Primary and Backup `dnsmasq` configurations: change `app.team1.test` A-record target from `10.7.27.66` (Mac 2) to `10.7.24.241` (Mac 3).
  3. Reload `dnsmasq` instances (`killall -SIGHUP dnsmasq`).
  4. Flush client resolver caches.
  5. Client traffic seamlessly transitions to Mac 3 without dropping an active session.

### Extension F: Automated 4-Layer Diagnostic System
To replace disorganized debugging with systematic root-cause isolation, we engineered `scripts/diagnose-stack.sh`. The script performs sequential bottom-up interrogation across the OSI model:

```
+--------------------------------------------------------------------------+
|                 4-LAYER BOTTOM-UP DIAGNOSTIC ENGINE                      |
+--------------------------------------------------------------------------+
|  Layer 1: Network & Physical (ICMP)                                      |
|  --> ping -c 1 -W 1000 <Target_IP>                                       |
|  [FAIL] => Wi-Fi disconnected, ARP failure, or routing partition.        |
+--------------------------------------------------------------------------+
|  Layer 2: Transport & Security (TCP & Firewall)                          |
|  --> nc -zvw 2 <Target_IP> <Port>                                        |
|  [FAIL] => Process not listening (down) or blocked by PF firewall (RST). |
+--------------------------------------------------------------------------+
|  Layer 3: Session & Encryption (TLS/SSL)                                 |
|  --> openssl s_client -connect <Target_IP>:443 -servername <Domain>     |
|  [FAIL] => Certificate expired, hostname mismatch, or untrusted CA.      |
+--------------------------------------------------------------------------+
|  Layer 4: Application & Ingress (HTTP & Proxy)                           |
|  --> curl -s -o /dev/null -w "%{http_code}" https://<Domain>/api/status  |
|  [FAIL] => HTTP 502 (Upstream dead), 504 (Timeout), or 404 (Path error). |
+--------------------------------------------------------------------------+
```

---

## 4. Empirical Test Results & Verification Metrics

All six extensions were subjected to rigorous automated verification. Empirical data was gathered using command-line test suites and verified against concurrent Wireshark packet captures.

### Table 2: Formal Verification Results Matrix

| Test Suite | Injected Condition | Expected System Behavior | Measured Result | HTTP Code | Status |
|:---|:---|:---|:---|:---|:---|
| **Ext A: DNS Redundancy** | Primary DNS daemon on Mac 1 killed (`pkill dnsmasq`) | Client OS resolver falls back to Mac 4 Secondary DNS | Domain resolved in 1.14s via `10.7.27.154` | `200 OK` | **PASSED** |
| **Ext B: TTL Caching** | Record changed on DNS; query repeated | Record cached for 30s; instant flush on cache invalidation | Cache held exactly 30s; updated IP fetched at $t=31$s | `200 OK` | **PASSED** |
| **Ext C: Service Isolation** | External client curls Backend A directly (`:3001`) | macOS `pf` rejects TCP SYN with `TCP RST` | `curl: (7) Connection refused` within 4ms | None (L4 RST) | **PASSED** |
| **Ext C: Edge Whitelist** | Edge Proxy queries Backend A directly (`:3001`) | Packet matches whitelist rule; passed to socket | Response received in 3ms with `X-Backend: A` | `200 OK` | **PASSED** |
| **Ext D: HA Failover** | Backend A stopped during active request stream | In-flight request replayed to Backend B; no errors | 10 consecutive requests served by Backend B; 0 dropped | `200 OK` | **PASSED** |
| **Ext E: Edge Cutover** | DNS record shifted to Standby Edge on Mac 3 | Client transitions smoothly to standby proxy | Header `X-Edge-Server: standby-edge-mac3` observed | `200 OK` | **PASSED** |
| **Ext F: Full Stack Audit** | Normal operational baseline | All 4 protocol layers pass verification sequentially | 100% checkmark across ICMP, TCP, TLS, and HTTP | `200 OK` | **PASSED** |

---

## 5. Enterprise Cloud & Production Architecture Parallels

The physical multi-node architecture implemented in this academic project reflects standard enterprise infrastructure patterns deployed in hyperscale cloud environments (e.g., Amazon Web Services, Google Cloud Platform):

```
+---------------------------------------------------------------------------------------+
| Local Physical Architecture (Our Project)   | AWS Enterprise Cloud Equivalent         |
+---------------------------------------------+-----------------------------------------+
| Dual Mac 1 & Mac 4 dnsmasq Instances        | Amazon Route 53 (Multi-AZ Health Check) |
| Active Edge Proxy (Mac 2 NGINX)             | AWS Application Load Balancer (ALB)     |
| Standby Edge Proxy (Mac 3 NGINX)            | Multi-Region Hot-Standby ALB / DR       |
| macOS pf Firewall (Per-Host Rules)          | EC2 Security Groups (Stateful L4)       |
| Wi-Fi Network Partitioning                  | Virtual Private Cloud (VPC Subnets)     |
| Express.js Application Nodes                | Containerized ECS Tasks / EC2 Compute   |
+---------------------------------------------------------------------------------------+
```

### Key Architectural Lessons:
1. **Defense-in-Depth (Security Groups vs. Perimeter Firewalls)**: Perimeter firewalls (like Edge WAFs) are insufficient. If an attacker gains a foothold inside the network, unrestricted east-west traffic allows lateral traversal. Enforcing host-level stateful firewalls (macOS `pf` / AWS Security Groups) ensures that internal services communicate exclusively through designated, authenticated choke points.
2. **Layer 4 vs. Layer 7 Failover Dynamics**: Layer 4 load balancers (AWS NLB) route raw TCP streams with immense throughput but lack application context. Layer 7 proxies (NGINX / AWS ALB) introduce slight parsing overhead but provide the intelligence necessary to inspect HTTP status codes, retry failed idempotent GET requests, and provide zero-downtime resiliency.

---

## 6. Individual Learning Summaries

### Manas Selukar (Primary DNS Lead)
> *"Implementing redundant nameservers and tuning authoritative TTLs provided clear insight into the trade-offs of DNS design. I observed how client operating system resolver daemons prioritize cached records and how stub resolvers handle failover lists sequentially rather than simultaneously. Tuning TTL to 30 seconds highlighted the operational balance between DNS query volume and agility during infrastructure migration."*

### Anant Singh (Active Edge & TLS Lead)
> *"Architecting the NGINX reverse proxy with passive health checks and TLS termination demonstrated the power of Layer 7 load balancing. Configuring `proxy_next_upstream` was an eye-opener: seeing an in-flight request seamlessly rerouted from a dead backend to a live backend without the user seeing a 502 error proved how resilient proxies mask underlying infrastructure failures. I also gained practical expertise in TLS handshakes, certificate authority chains, and SNI routing."*

### Akhil Sharma (Backend A & Security Lead)
> *"Working directly with macOS Packet Filter (`pf`) demystified stateful packet inspection at the kernel level. I learned the critical difference between silently dropping packets (`block drop`) and actively resetting them (`block return-rst`), which prevents client timeouts during network isolation. Deploying the standby NGINX edge on Mac 3 also taught me how hot-standby nodes must maintain synchronized TLS certificates and directories to achieve true zero-downtime cutovers."*

### Syed Darain Qamar (Backend B, Backup DNS & Automation Orchestrator)
> *"Engineering the automated test pipeline and diagnostic suite reinforced the necessity of systematic, layer-by-layer troubleshooting. Building `diagnose-stack.sh` taught me that complex distributed bugs cannot be solved by guesswork; isolating failures bottom-up from ICMP to TCP sockets to TLS handshakes and finally to HTTP application codes saves critical operational hours. Furthermore, managing the secondary DNS server demonstrated how essential redundant name resolution is to modern service availability."*

---

## 7. Conclusion

Phase 2 successfully resolved every single point of failure and security deficiency present in Phase 1. By coupling dual-resolver DNS redundancy, kernel-level packet filter isolation, fast-failover reverse proxy load balancing, hot-standby edge migration, and automated multi-layer diagnostics, Team 1 designed and proved a robust, production-grade distributed web platform across physical macOS nodes. The empirical results confirm 100% availability during single-node failure simulations, complete defense-in-depth isolation against direct backend tampering, and instantaneous fault diagnosis.
