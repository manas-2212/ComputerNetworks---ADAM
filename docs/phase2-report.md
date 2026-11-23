# Team Adam (Team 1) — Phase 2 Final Report
## Private Network Service Platform: Harden, Recover & Troubleshoot

---

## 1. What Changed from Phase 1 to Phase 2

In Phase 1, the platform established a single-path network: Client $\rightarrow$ Primary DNS $\rightarrow$ Edge NGINX $\rightarrow$ Backends A & B. While functional, it had multiple single points of failure and zero layer-4 network isolation.

In Phase 2, we hardened the architecture with five mandatory resilience extensions:
1. **Redundant DNS**: Introduced a secondary `dnsmasq` resolver on Mac 4. If Mac 1 crashes, clients automatically fall back to Mac 4.
2. **DNS TTL & Controlled Cutover**: Lowered authoritative TTL to 30 seconds to demonstrate client caching behavior and rapid zero-downtime cutover.
3. **Service Isolation via macOS Packet Filter (`pf`)**: Configured kernel-level packet filter rules on backend nodes. Only Mac 2 (the Edge Reverse Proxy) is permitted to connect to ports 3001 and 3002; direct client connections are blocked and reset.
4. **High-Availability Failover**: Upgraded NGINX with fast passive health checks (`max_fails=1 fail_timeout=5s`) and upstream retries (`proxy_next_upstream error timeout http_502 http_503`). When Backend A is killed, in-flight requests immediately route to Backend B without client-visible 502 errors.
5. **Controlled Edge Migration**: Established a Standby NGINX instance on Mac 3 and demonstrated DNS cutover with zero downtime.

---

## 2. Resilience Tests and Results

| Test / Extension | Injected Condition | Expected Observation | Actual Result | Status |
|---|---|---|---|---|
| **Extension A (Backup DNS)** | Primary DNS (`dnsmasq` on Mac 1) stopped | Client queries resolve via Mac 4 Backup DNS | Resolves to `10.7.21.52` via secondary resolver within 1.2s | **PASSED** |
| **Extension B (TTL & Caching)** | DNS record modified on Mac 1 from `.52` to `.99` | Client returns cached `.52` until 30s TTL expires; flushes immediately on demand | Cache maintained for 30s; instant cutover observed after `dscacheutil -flushcache` | **PASSED** |
| **Extension C (Service Isolation)** | Client attempts direct connection to `http://<MAC3_IP>:3001/` | macOS `pf` firewall drops connection (`Connection reset by peer`) | Port 3001 and 3002 direct access blocked; Edge ingress HTTP 200 OK | **PASSED** |
| **Extension D (HA Failover)** | Backend A stopped mid-traffic | NGINX forwards request to Backend B transparently | 100% requests succeed with `X-Backend: B`. Zero HTTP 502 Bad Gateways | **PASSED** |
| **Extension E (Edge Cutover)** | DNS repointed to Standby NGINX on Mac 3 | Client transitions to Standby Edge | Responses show `X-Edge-Proxy: nginx-standby-mac3` | **PASSED** |

---

## 3. Systematic Troubleshooting Methodology (Extension F)

Our team implemented an automated 4-layer diagnostic suite (`scripts/diagnose-stack.sh`):
1. **Layer 1 (Application / DNS)**: Query local resolver and direct DNS IPs. Distinguish between DNS failure (name resolution fails) vs Application failure (IP reachable, service down).
2. **Layer 2 (Network & Transport / IP & TCP)**: Test ICMP ping reachability and TCP socket handshake (`nc -zvw 2 <ip> <port>`).
3. **Layer 3 (Session & Security / TLS)**: Perform OpenSSL handshake (`openssl s_client`), verify certificate authority trust, expiry, and SNI matching.
4. **Layer 4 (Application / HTTP & Proxy)**: Inspect HTTP status codes (200, 304, 502 Bad Gateway, 504 Timeout), examine reverse proxy error logs, and check backend response headers.

---

## 4. Learning Summary (One Paragraph per Extension)

* **Extension A (Backup DNS Resolver)**: Implementing a secondary resolver highlighted how client stub resolvers handle failover lists. Unlike load balancers, DNS client resolvers query primary first and only fall back upon timeout, teaching us the importance of quick timeouts in high-availability resolver configurations.
* **Extension B (DNS TTL & Cache Invalidation)**: Demonstrating short TTLs illustrated the trade-off between DNS query volume and agility during infrastructure migration. We observed how operating system resolver daemons (`mDNSResponder`) enforce caching independent of application requests.
* **Extension C (Service Isolation / Firewall Rules)**: Authoring macOS `pf` packet filter rules gave us hands-on experience with defense-in-depth security. In enterprise architectures, internal microservices should never be directly accessible from untrusted client networks.
* **Extension D (High-Availability Failover)**: Configuring NGINX passive health checks taught us how reverse proxies mask backend instability from end users. We identified that the Edge itself remains a Single Point of Failure (SPOF) and explored enterprise solutions like VRRP, Keepalived, and Anycast BGP.
* **Extension E (Controlled Edge Migration)**: Performing a DNS-based cutover to a standby edge showed us how zero-downtime maintenance is executed in production systems without purchasing duplicate hardware.
* **Extension F (Fault Challenge)**: Isolating unknown injected faults taught us the discipline of strict bottom-up diagnostic methodology, preventing guesswork by validating the protocol stack layer by layer.
