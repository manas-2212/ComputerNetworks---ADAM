# ComputerNetworks---ADAM

# Team 1 — Private LAN Networking & Service Infrastructure

A four-node private network implementing centralized DNS, HTTPS ingress, reverse proxying, round-robin load balancing, backend services, caching, and network-level verification.

---

## Overview

This project demonstrates a complete service architecture operating entirely within a private LAN.

```text
                         Private Wi-Fi / LAN
                                │
                    ┌───────────┴───────────┐
                    │                       │
              Mac 1 — DNS            Mac 2 — Edge
             10.7.17.68              10.7.21.52
              dnsmasq                 nginx :443
                    │                       │
                    │              ┌────────┴────────┐
                    │              │                 │
                    │        Backend A          Backend B
                    │        10.7.4.37:3001    10.7.13.20:3002
                    │
             Private DNS
          app.team1.test
          api.team1.test
