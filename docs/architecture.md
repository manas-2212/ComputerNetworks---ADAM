# Team Adam (Team 1) — Network Architecture Document
## Extended for Phase 2: Resilience, Service Isolation & Disaster Recovery

---

## 1. Network Topology (Phase 2)

Phase 2 enhances the Phase 1 topology by adding:
1. **Redundant Secondary DNS Resolver** (`dnsmasq` on Mac 4).
2. **Service Isolation Packet Filters** (`pf` firewalls on Mac 3 and Mac 4).
3. **Standby Edge Proxy Node** (Standby NGINX on Mac 3).

```text
                                  ┌────────────────────────────────┐
                                  │   PRIMARY DNS (Mac 1, Manas)   │
                                  │   IP: MAC1_IP :53 (dnsmasq)    │
                                  │  TTL: 30s (Short expiration)   │
                                  └───────────────┬────────────────┘
                                                  │ (Active/Passive Failover)
                                  ┌───────────────▼────────────────┐
                                  │   BACKUP DNS (Mac 4, Darain)   │
                                  │   IP: MAC4_IP :53 (dnsmasq)    │
                                  │  Identical private zone records│
                                  └───────────────┬────────────────┘
                                                  │
                                                  │ Resolves: app.team1.test -> MAC2_IP
                                                  ▼
                                  ┌────────────────────────────────┐
                                  │     PRIMARY EDGE (Mac 2, Anant)│
                                  │   IP: MAC2_IP :443 (NGINX)     │
                                  │  TLS Termination + HA Upstream │
                                  └───────────────┬────────────────┘
                                                  │
                          ┌───────────────────────┴───────────────────────┐
                          │ (Allowed: Only MAC2_IP via pf firewall)       │
                          │ (Blocked: All other direct LAN connections)   │
                          ▼                                               ▼
         ┌─────────────────────────────────┐             ┌─────────────────────────────────┐
         │       BACKEND A (Mac 3, Akhil)  │             │      BACKEND B (Mac 4, Darain)  │
         │   IP: MAC3_IP :3001 (Node REST) │             │   IP: MAC4_IP :3002 (Node REST) │
         │   macOS pf: Only MAC2_IP allowed│             │   macOS pf: Only MAC2_IP allowed│
         │   [Standby NGINX Edge for Cutover]│           │   [Runs Backup DNS Resolver]    │
         └─────────────────────────────────┘             └─────────────────────────────────┘
```

---

## 2. Machine & Service Inventory

| Node | Owner | Role | Services & Ports | Security / Resilience Features |
|---|---|---|---|---|
| **Mac 1** | **Manas Selukar** | Primary DNS Resolver | `dnsmasq` (UDP/TCP 53) | Short TTL (`30s`), dynamic cutover support. |
| **Mac 2** | **Anant Singh** | Edge Reverse Proxy & LB | `nginx` (TCP 80, 443) | TLS termination, passive health checks (`fail_timeout=5s`), `proxy_next_upstream`. |
| **Mac 3** | **Akhil Sharma** | Backend A & Standby Edge | Node.js Express (`:3001`), Standby NGINX (`:443`) | macOS `pf` firewall rules blocking direct client connections; Standby edge migration host. |
| **Mac 4** | **Syed Darain Qamar** | Backend B, Backup DNS & Client | Node.js Express (`:3002`), Backup `dnsmasq` (`:53`), Test Runner | macOS `pf` firewall isolation; automated test runner & Wireshark packet capture. |

---

## 3. Protocol Flow & Request Journey

```text
1. Client (Mac 4) ──[ UDP :53 ]──> Mac 1 (Primary DNS)
   └─ (If Mac 1 down) ───────────> Mac 4 (Backup DNS)
   └─ Returns: MAC2_IP (TTL = 30 seconds)

2. Client ──[ TCP :443 Handshake ]──> Mac 2 (Edge NGINX)
   └─ SYN -> SYN-ACK -> ACK

3. Client ──[ TLS 1.3 Handshake ]───> Mac 2 (Edge NGINX)
   └─ ClientHello (SNI: app.team1.test) -> ServerHello -> Cert -> Handshake Finished

4. Client ──[ Encrypted HTTP GET ]──> Mac 2 (Edge NGINX)
   └─ NGINX terminates TLS, applies Round-Robin load balancing.

5. Mac 2 ──[ Internal HTTP GET ]────> Mac 3 (:3001) or Mac 4 (:3002)
   └─ Packet Filter allows MAC2_IP; blocks rogue client IPs.

6. Backend ──[ JSON + X-Backend ]───> Mac 2 ──[ Encrypted HTTPS ]──> Client
```
