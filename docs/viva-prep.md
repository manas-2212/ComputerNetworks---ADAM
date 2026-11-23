# Team Adam — Complete Viva & Presentation Preparation Guide

This guide prepares **Manas, Anant, Akhil, and Syed Darain** for the Phase 2 Viva (10 marks individual) and final presentation. Every team member must understand both their own component and the entire end-to-end stack.

---

## Part 1: Core Networking Concepts & Protocol Mapping

### 1. The Full Request Journey (Step-by-Step)
When a user types `https://app.team1.test` in the browser:
1. **Application Layer (DNS)**: Browser checks local OS cache (`mDNSResponder`). If missed, client sends a DNS query (UDP port 53) to `10.7.17.68` (Manas). `dnsmasq` responds with `10.7.21.52` (Anant, Edge).
2. **Transport Layer (TCP Handshake)**: Client initiates a TCP connection to `10.7.21.52:443`:
   - Client sends `SYN` (with client ISN).
   - NGINX sends `SYN-ACK` (acknowledging client ISN + server ISN).
   - Client sends `ACK`. Handshake complete.
3. **Session/Transport Layer (TLS Handshake)**:
   - **ClientHello**: TLS version, supported cipher suites, SNI (`server_name = app.team1.test`), client random.
   - **ServerHello**: Chosen cipher suite, server random.
   - **Certificate**: NGINX sends its X.509 certificate signed by our trusted local CA.
   - **Key Exchange**: Ephemeral Diffie-Hellman (ECDHE) keys exchanged to establish symmetric session key.
   - **Finished (Encrypted)**: Both sides verify handshake integrity and switch to symmetric AES-GCM encryption.
4. **Application Layer (HTTP & Reverse Proxy)**:
   - Client sends encrypted HTTP GET request.
   - NGINX decrypts payload, inspects path, applies load balancing (round-robin), and forwards request to either Mac 3 (`10.7.24.127:3001`) or Mac 4 (`10.7.13.20:3002`).
   - Selected Backend returns JSON with `X-Backend: A` or `B` and cache headers (`Cache-Control: max-age=60`).
   - NGINX encrypts the response and sends it back to the client.

---

## Part 2: Individual Viva Questions & Expected Answers

### 👤 Manas Selukar (Mac 1 — DNS Specialist)
- **Q: Why does DNS use UDP port 53 instead of TCP?**
  - **Answer**: DNS queries are lightweight (single request/response). UDP is connectionless and avoids the 3-way handshake overhead, minimizing latency. TCP is used only for zone transfers (AXFR) or when responses exceed 512 bytes (or EDNS0 limits).
- **Q: What is DNS TTL and what happens during a record cutover?**
  - **Answer**: TTL (Time-To-Live) tells recursive resolvers and client OS caches how long to store the record before querying authoritative servers again. During migration, clients with cached records will continue hitting the old IP until their local TTL reaches zero.
- **Q: How does Backup DNS resolver failover work?**
  - **Answer**: Client network settings list multiple nameservers (`nameserver 10.7.17.68`, `nameserver 10.7.13.20`). If the primary fails to respond within a timeout (usually 1-2s), the client resolver automatically queries the secondary resolver.
- **Q: What is the difference between a DNS failure and an Application failure?**
  - **Answer**: In a DNS failure, the client cannot translate the domain name to an IP (e.g. `NXDOMAIN` or timeout; `ping` by IP still works). In an application failure, DNS resolution succeeds, but the target IP returns connection refused (TCP down) or HTTP 502/503.

### 👤 Anant Singh (Mac 2 — Edge, NGINX & Load Balancer Lead)
- **Q: What is the difference between Layer 4 and Layer 7 Load Balancing?**
  - **Answer**: Layer 4 load balancing routes traffic based on IP addresses and TCP/UDP ports without inspecting application data. Layer 7 (which NGINX is doing here) terminates TLS, parses HTTP headers, cookies, URLs, and can perform intelligent routing, caching, and header injection (`X-Forwarded-For`).
- **Q: How does NGINX detect backend failure and route traffic safely?**
  - **Answer**: Using passive health checks in upstream: `max_fails=1 fail_timeout=5s` combined with `proxy_next_upstream error timeout http_502 http_503;`. When Backend A drops or times out, NGINX transparently re-routes that exact in-flight request to Backend B so the end client never sees an error.
- **Q: Where is TLS terminated and why?**
  - **Answer**: TLS is terminated at the NGINX edge on Mac 2. This offloads cryptographic burden from backends, centralizes certificate management, and allows the reverse proxy to inspect HTTP headers and balance traffic.
- **Q: What is the Single Point of Failure (SPOF) in this architecture and how is it solved in production?**
  - **Answer**: Mac 2 (NGINX) is a SPOF. If Mac 2 crashes, the entire platform goes down. In production, this is solved by running redundant edge proxies using VRRP/Keepalived (Virtual IP failover), DNS Round Robin across multiple edge IPs, Anycast BGP routing, or cloud managed load balancers (AWS ALB/NLB multi-AZ).

### 👤 Akhil Sharma (Mac 3 — Backend A, Security & Isolation Lead)
- **Q: What is Service Isolation and why is it important in a multi-tier network?**
  - **Answer**: Backends should never be directly accessible to clients over the LAN; they should only communicate with the reverse proxy. This prevents attackers from bypassing authentication, WAF rate limits, and TLS termination, and protects internal application ports.
- **Q: How did you implement Service Isolation on macOS?**
  - **Answer**: Using macOS Packet Filter (`pf`). We added rules allowing incoming TCP to port 3001/3002 only from Mac 2's IP (`10.7.21.52`), and immediately blocking/resetting connections from all other IP addresses (`block return-rst in quick proto tcp from any to any port 3001`).
- **Q: What HTTP status code does the client get when both backends are down vs when the firewall blocks access?**
  - **Answer**: If both backends are down, NGINX returns `502 Bad Gateway`. If a client tries to connect *directly* to the backend port with the firewall enabled, the TCP connection is refused (`Connection reset by peer` or connection timeout), proving isolation at Layer 4.
- **Q: What is an ephemeral port?**
  - **Answer**: An ephemeral port is a short-lived transport port allocated automatically by the client OS IP stack (ports 49152–65535 on macOS) to establish a socket pair `(Client_IP:Ephemeral_Port, Server_IP:443)`.

### 👤 Syed Darain Qamar (Mac 4 — Backend B, Backup DNS Lead & Client Automation)
- **Q: How does HTTP Caching work with `Cache-Control` and `ETag`?**
  - **Answer**: `Cache-Control: max-age=60` tells the browser/client that the response is fresh for 60 seconds. Subsequent requests within 60s are served from local cache. When expired, the client sends a conditional request with `If-None-Match: <etag>` or `If-Modified-Since`. If unchanged, the server responds with `304 Not Modified`, saving bandwidth.
- **Q: What role does SNI (Server Name Indication) play in TLS?**
  - **Answer**: SNI is a TLS extension in the ClientHello packet where the client specifies which hostname it is trying to reach. This allows a single NGINX edge server with one IP address to host multiple distinct domains (`app.team1.test`, `api.team1.test`) with different SSL certificates.
- **Q: How does the standby edge migration (Extension E) work?**
  - **Answer**: A replica NGINX is started on another Mac. The DNS record is updated. Because of DNS caching, clients with active leases still hit the old edge, while clients with fresh lookups immediately hit the standby edge. This demonstrates zero-downtime maintenance.
- **Q: How did you capture and prove packet flow in Wireshark?**
  - **Answer**: We filtered by `dns || tcp.port == 443 || tcp.port == 3001 || tcp.port == 3002`. We verified the DNS A record response, the TCP 3-way handshake (`SYN`, `SYN-ACK`, `ACK`), the TLS Client/ServerHello, and encrypted application data records.
