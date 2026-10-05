# Team 1 — Network Architecture

> Private LAN service platform implementing centralized DNS, HTTPS ingress,
> reverse proxying, and backend load balancing.

---

## 1. Network Topology

The system consists of four macOS machines connected to the same private
Wi-Fi/LAN.

![Network Topology](topology.png)

The architecture follows a single-entry-point design:

- Mac 1 provides private DNS resolution.
- Mac 2 is the public entry point and runs nginx.
- Mac 3 provides Backend A.
- Mac 4 provides Backend B.
- Clients access services through the private domain name rather than
  connecting directly to backend IP addresses.

---

## 2. Machine & Service Inventory

| Machine | Role | Private IP | Services |
|---|---|---|---|
| Mac 1 — Manas | Private DNS + Test Client | `10.7.17.68` | dnsmasq :53 |
| Mac 2 — Anant | Edge / Reverse Proxy / Load Balancer | `10.7.21.52` | nginx :80 / :443 |
| Mac 3 — Akhil | Backend A | `10.7.24.127` | REST API :3001 |
| Mac 4 — Darain | Backend B + Test Client | `10.7.13.20` | REST API :3002 |

### Private DNS Records

| Hostname | Resolves To | Purpose |
|---|---|---|
| `app.team1.test` | `10.7.21.52` | Main application entry point |
| `api.team1.test` | `10.7.21.52` | API entry point |

Mac 1 acts as the team's private DNS resolver using `dnsmasq`.

---

## 3. Request Flow

A request to the application follows this path:

```text
Client
   │
   │ DNS Query
   │ UDP :53
   ▼
Mac 1 — dnsmasq
10.7.17.68
   │
   │ app.team1.test
   │ → 10.7.21.52
   ▼
Mac 2 — nginx Edge
10.7.21.52
   │
   │ TCP :443
   │ TLS
   │ HTTP
   ▼
┌───────────────────────┐
│     Load Balancer     │
│        nginx          │
└───────────┬───────────┘
            │
       ┌────┴────┐
       ▼         ▼
 Backend A   Backend B
 :3001        :3002
 Akhil        Darain
