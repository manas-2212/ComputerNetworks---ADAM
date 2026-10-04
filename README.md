# ComputerNetworks---ADAM

# Team 1 — Private LAN Networking & Service Infrastructure

A four-node private network implementing centralized DNS, HTTPS ingress, reverse proxying, round-robin load balancing, backend services, caching, and network-level verification.

---

## Overview

This project demonstrates a complete service architecture operating entirely within a private LAN.

```text
CLIENT
Team Member Mac
        │
        │ DNS :53
        ▼
DNS SERVER
Manas
10.7.17.68
        │
        │ app.team1.test → 10.7.21.52
        ▼
EDGE · NGINX
Anant
10.7.21.52
        │
        │ HTTPS :443
        ├───────────────┐
        ▼               ▼
BACKEND A          BACKEND B
Akhil              Darain
10.7.4.37:3001     10.7.13.20:3002
