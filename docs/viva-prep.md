# Team Adam — Ultimate Viva & Presentation Preparation Runbook

> **Course**: Computer Networks Laboratory  
> **Project**: High-Availability, Hardened Multi-Tier Distributed Web Platform (Phases 1 & 2)  
> **Team Members**: Manas Selukar, Anant Singh, Akhil Sharma, Syed Darain Qamar  
> **Topology**: 4 Physical macOS Nodes communicating across local Wi-Fi/LAN  

---

## Table of Contents
1. [What We Did in Phase 2 (Hardening, Recovery & Troubleshooting)](#1-what-we-did-in-phase-2)
2. [Team Roles & Individual Contributions](#2-team-roles--individual-contributions)
3. [Core Computer Networking Concepts & Knowledge Base](#3-core-computer-networking-concepts--knowledge-base)
   - [3.1 DNS Architecture & dnsmasq](#31-dns-architecture--dnsmasq)
   - [3.2 NGINX & Reverse Proxy Architecture](#32-nginx--reverse-proxy-architecture)
   - [3.3 Digital Certificates, PKI & TLS Handshake](#33-digital-certificates-pki--tls-handshake)
   - [3.4 Packet Filtering & Firewall Isolation (macOS PF)](#34-packet-filtering--firewall-isolation-macos-pf)
   - [3.5 Load Balancing Algorithms & Health Check Mechanisms](#35-load-balancing-algorithms--health-check-mechanisms)
   - [3.6 Cloud & Enterprise Infrastructure Parallels (VPC, Security Groups, Route Tables, IGW, EC2)](#36-cloud--enterprise-infrastructure-parallels)
   - [3.7 Transport Layer Deep Dive: TCP Sockets, States & HTTP Headers](#37-transport-layer-deep-dive-tcp-sockets-states--http-headers)
4. [Tough Viva Follow-Up Questions & Model Answers](#4-tough-viva-follow-up-questions--model-answers)
5. [Pre-Flight Verification Checklist Before the Final Presentation](#5-pre-flight-verification-checklist-before-the-final-presentation)
6. [Faculty Ingested Error Guide & Live Fault-Injection Playbook](#6-faculty-ingested-error-guide--live-fault-injection-playbook)

---

## 1. What We Did in Phase 2

In **Phase 1**, we built a baseline working prototype: a DNS server resolving `app.team1.test`, an NGINX reverse proxy terminating TLS with self-signed certificates, and two Express backend instances behind a basic round-robin upstream pool.

However, Phase 1 had critical architectural vulnerabilities and operational limitations:
- **Single Points of Failure (SPOFs)**: If the primary DNS server or Edge proxy crashed, the entire platform was knocked offline.
- **Unshielded Internal Backends**: Any client on the Wi-Fi network could bypass the Edge proxy and query `http://<backend_ip>:3001` or `:3002` directly, bypassing TLS, logging, and load balancing.
- **Slow Failure Recovery**: If a backend crashed, users experienced intermittent `502 Bad Gateway` errors due to standard default upstream timeouts.
- **Stale DNS Caching**: Long TTL defaults prevented rapid DNS cutovers during emergencies or migrations.
- **Manual Debugging**: No structured way to isolate whether a failure occurred at the Physical, Network, Transport, or Application layer.

### The Phase 2 Hardening Solutions:
1. **DNS Redundancy (Extension A)**: Deployed a dual-nameserver architecture with Primary DNS on Mac 1 and Secondary/Backup DNS on Mac 4, enabling seamless client fallback.
2. **Aggressive TTL Management (Extension B)**: Configured low TTLs (`local-ttl=30`) and tested caching and cache-flushing dynamics across local client resolvers.
3. **Defense-in-Depth Service Isolation (Extension C)**: Implemented kernel-level Packet Filter (`pf`) firewalls on Mac 3 and Mac 4 to reject any TCP traffic on backend ports (3001 & 3002) not originating from the designated Edge Proxy IP.
4. **Zero-Downtime High-Availability Failover (Extension D)**: Hardened NGINX upstream configuration with fast passive health checks (`fail_timeout=5s`, `max_fails=1`, `proxy_connect_timeout 2s`) and seamless failover (`proxy_next_upstream error timeout http_502 http_503`), ensuring zero dropped requests during backend outages.
5. **Standby Edge Migration & DNS Cutover (Extension E)**: Configured a replica hot-standby NGINX edge on Mac 3 with synchronized TLS certificates, executing a live DNS cutover with zero downtime.
6. **Automated 4-Layer Diagnostic System (Extension F)**: Built an automated stack diagnostic script (`diagnose-stack.sh`) verifying connectivity sequentially across L1/L2 (Ping/ICMP), L3/L4 (Port & TCP socket state), Application (DNS & HTTP status), and Security (Firewall rules).

---

## 2. Team Roles & Individual Contributions

```
+-----------------------------------------------------------------------------------------+
|                                    TEAM 1 TOPOLOGY                                      |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|   [Mac 1 - Manas]             [Mac 2 - Anant]              [Mac 3 - Akhil]              |
|   Primary DNS (dnsmasq)       Active Edge Proxy (NGINX)    Backend A (:3001)            |
|   Port: 53 (UDP/TCP)          Ports: 80, 443               Standby Edge (:443)          |
|   Role: DNS Gatekeeper        Role: TLS & Load Balancer    PF Firewall Isolated         |
|             \                       /                               |                   |
|              \                     /                                |                   |
|               \                   /                                 |                   |
|              [Mac 4 - Syed Darain] <--------------------------------+                   |
|              Backend B (:3002)                                                          |
|              Backup DNS (dnsmasq :53)                                                   |
|              PF Firewall Isolated                                                       |
|              Automation, Test Scripts & Diagnostics                                     |
|                                                                                         |
+-----------------------------------------------------------------------------------------+
```

### 👤 Manas Selukar (Mac 1 — Primary DNS Specialist & Traffic Gatekeeper)
- **Component Owned**: Primary DNS Server running `dnsmasq` (`config/dnsmasq/dnsmasq-phase2-primary.conf`).
- **Key Tasks Executed**:
  - Configured authoritative local resolution for the custom `.test` top-level domain (`team1.test`, `app.team1.test`, `api.team1.test`).
  - Tuned DNS record caching by setting `local-ttl=30` to facilitate rapid record changes and testing without stale client states.
  - Configured upstream public DNS forwarding (`server=1.1.1.1`, `server=8.8.8.8`) to ensure standard external internet traffic remained resolvable.
  - Demonstrated primary DNS failure simulation (`pkill dnsmasq`) to validate client fallback to the backup nameserver on Mac 4.

### 👤 Anant Singh (Mac 2 — Active Edge Reverse Proxy, TLS Architect & Load Balancer Lead)
- **Component Owned**: Primary NGINX Reverse Proxy (`config/nginx/nginx-phase2.conf`).
- **Key Tasks Executed**:
  - Configured TLS termination on port 443 using custom RSA 2048-bit X.509 certificates generated under the team's self-signed Root CA.
  - Implemented HTTP-to-HTTPS permanent redirect (HTTP 301) on port 80 to enforce transport security.
  - Designed the High-Availability Upstream block balancing traffic across Backend A (Mac 3) and Backend B (Mac 4).
  - Configured aggressive passive health check thresholds (`fail_timeout=5s`, `max_fails=1`, `proxy_connect_timeout 2s`) and `proxy_next_upstream` retry logic to eliminate user-facing 502 errors when a backend dies.
  - Injected standard proxy tracking headers (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) to maintain client visibility behind the proxy.

### 👤 Akhil Sharma (Mac 3 — Backend A Lead, Security Isolation & Hot Standby Edge)
- **Component Owned**: Backend Application Service A (Node.js/Express on port 3001) & Standby Edge Proxy (`config/nginx/nginx-standby.conf`).
- **Key Tasks Executed**:
  - Implemented Backend A web service returning structured JSON with the node identity header `X-Backend: A`.
  - Configured kernel-level packet filtering with macOS `pf` (`config/firewall/pf-rules.conf`), dropping unauthorized connections to port 3001 while permitting traffic exclusively from Mac 2.
  - Deployed and pre-warmed a Hot Standby Edge NGINX instance on port 443 with matching TLS certificates and log directory structures.
  - Injected `X-Edge-Server: standby-edge-mac3` header to visually demonstrate successful traffic migration during the Extension E cutover.

### 👤 Syed Darain Qamar (Mac 4 — Backend B Lead, Backup DNS Specialist & Automation Orchestrator)
- **Component Owned**: Backend Application Service B (Node.js/Express on port 3002), Secondary/Backup DNS Server (`config/dnsmasq/dnsmasq-phase2-backup.conf`), and Automation Test Suite.
- **Key Tasks Executed**:
  - Implemented Backend B web service returning structured JSON with `X-Backend: B` and caching headers (`Cache-Control`, `ETag`).
  - Configured and operated the Secondary DNS Server on port 53 to provide seamless failover when Mac 1's DNS halts.
  - Applied macOS `pf` firewall rules protecting port 3002 from direct external LAN access.
  - Engineered the entire automated operational and testing pipeline:
    - `update-ips.sh`: Dynamic Wi-Fi IP discovery and config propagation.
    - `verify-phase1.sh`: Pre-flight verification across all 6 Phase 1 criteria.
    - `apply-firewall.sh` / `rollback-firewall.sh`: Automated security state enforcement.
    - `test-ha-failover.sh`: Zero-downtime failover verification under active failure injection.
    - `diagnose-stack.sh`: 4-layer diagnostic engine (L1/L2, L3/L4, Application, Security).
  - Captured and curated all Wireshark packet traces (`.pcap`) and proof screenshots.

---

## 3. Core Computer Networking Concepts & Knowledge Base

Every team member must be fluent in these foundational concepts, their theoretical definitions, and how they map directly to our project.

```
+-----------------------------------------------------------------------------------------+
|                               OSI vs TCP/IP LAYER MAPPING                               |
+-----------------------------------------------------------------------------------------+
| OSI Layer             | TCP/IP Layer        | Implementation in Our Project             |
+-----------------------+---------------------+-------------------------------------------+
| 7. Application        | Application         | HTTP/1.1, DNS (dnsmasq), Express APIs     |
| 6. Presentation       | Application         | TLS 1.3 / OpenSSL Encryption              |
| 5. Session            | Application         | TCP Sockets, TLS Session Resumption       |
| 4. Transport          | Transport           | TCP (Ports 80, 443, 3001, 3002), UDP (53) |
| 3. Network            | Internet            | IPv4 Addressing, ICMP (Ping), macOS PF    |
| 2. Data Link          | Network Access      | Wi-Fi (802.11), Ethernet Frames, ARP      |
| 1. Physical           | Network Access      | Radio Frequency (Wi-Fi), NIC hardware     |
+-----------------------------------------------------------------------------------------+
```

---

### 3.1 DNS Architecture & `dnsmasq`

#### What is DNS?
The **Domain Name System (DNS)** is a distributed, hierarchical naming database that translates human-readable hostnames (e.g., `app.team1.test`) into machine-routable IP addresses (e.g., `10.7.27.66`).

#### Recursive vs. Authoritative Resolvers
- **Authoritative DNS**: The official server that holds the master copy of DNS records for a given zone (e.g., our `dnsmasq` instance holding the `.test` domain records). It answers queries with authoritative information.
- **Recursive DNS Resolver**: The client-facing server that traverses the DNS hierarchy on behalf of the client (from Root `.` to TLD `.test` to Authoritative) to resolve an unknown address and caches the result.

#### Why UDP Port 53? When Does it Use TCP?
- **UDP (User Datagram Protocol)** is used by default because DNS lookups are small, single-request/single-response transactions. UDP avoids the latency overhead of the 3-way TCP handshake.
- **TCP Port 53** is utilized when:
  1. The response payload exceeds **512 bytes** (traditional limit without EDNS0) and the server sets the Truncated bit (`TC=1`), forcing the client to retry over TCP.
  2. Performing **Zone Transfers (AXFR/IXFR)** between primary and secondary nameservers, where reliable data transmission is required.

#### What is `dnsmasq`?
`dnsmasq` is a lightweight, low-footprint DNS forwarder, caching resolver, and DHCP server designed for local network infrastructure. Rather than maintaining heavy BIND zone files, `dnsmasq` can read standard hosts files and synthesize forward/reverse lookups with minimal overhead.

#### DNS Record Types Used:
- **A Record (Address)**: Maps an IPv4 domain name to a 32-bit IP address (e.g., `app.team1.test -> 10.7.27.66`).
- **CNAME (Canonical Name)**: An alias that points one domain name to another domain name.

#### Time-To-Live (TTL) & Caching Dynamics
- **TTL** specifies the number of seconds a DNS record may be cached by intermediate recursive resolvers and client OS caches (such as macOS `mDNSResponder`) before re-querying the authoritative server.
- **Why we tuned TTL to 30 seconds (`local-ttl=30`)**: In production, low TTLs are configured prior to planned infrastructure migrations. High TTLs (e.g., 86400 seconds) cause clients to send traffic to decommissioned servers long after DNS records are changed.

---

### 3.2 NGINX & Reverse Proxy Architecture

#### Reverse Proxy vs. Forward Proxy
```
Forward Proxy:
[Client A] \
[Client B]  --> [Forward Proxy]  --> [Public Internet / Target Server]
[Client C] /
(Protects/masks clients, filters outbound traffic, bypasses censorship)

Reverse Proxy:
                                     /--> [Internal Backend A]
[External Client] --> [Reverse Proxy] --> [Internal Backend B]
                                     \--> [Internal Backend C]
(Protects/masks servers, terminates TLS, load balances, caches responses)
```
- A **Forward Proxy** sits in front of clients and acts on their behalf to access external servers.
- A **Reverse Proxy** (NGINX) sits in front of backend servers and intercepts client requests, hiding internal topology, terminating TLS, enforcing security policies, and distributing load.

#### Why Terminate TLS at the Reverse Proxy?
1. **Cryptographic Offloading**: RSA/ECDHE asymmetric handshakes consume significant CPU cycles. Terminating encryption at the Edge frees internal backend CPUs to run business logic.
2. **Centralized Certificate Management**: Only the Edge proxy holds the private keys and renewal hooks, preventing key sprawl across internal nodes.
3. **Deep Packet Inspection & Layer 7 Routing**: The proxy can inspect decrypted HTTP headers, paths (`/api` vs `/static`), cookies, and request methods to make intelligent routing decisions.

#### Upstream Tracking Headers
Because a reverse proxy initiates a new TCP connection to the backend, the backend's socket sees the proxy's IP as the client. To preserve origin metadata, NGINX injects:
- `Host`: Keeps the original requested hostname intact.
- `X-Real-IP`: Captures the actual client's IP address.
- `X-Forwarded-For`: Appends client and proxy chain IPs (`client, proxy1, proxy2`).
- `X-Forwarded-Proto`: Informs the backend whether the user connected via `http` or `https`.

---

### 3.3 Digital Certificates, PKI & TLS Handshake

#### What is an X.509 Certificate?
An **X.509 Certificate** is a cryptographically bound digital document that associates a public key with an identity (such as a domain name `app.team1.test`). It contains:
- **Subject**: Domain owner identity (`CN=app.team1.test`, SANs).
- **Issuer**: The Certificate Authority (CA) that validated the identity and digitally signed the cert.
- **Public Key**: The server's public key (RSA 2048-bit in our setup).
- **Validity Period**: `NotBefore` and `NotAfter` timestamps.
- **Digital Signature**: A hash of the certificate signed with the CA's private key.

#### Public Key vs. Private Key
- **Private Key (`.key`)**: Kept strictly confidential on the server. Used to decrypt data or generate cryptographic signatures.
- **Public Key / Certificate (`.crt`)**: Distributed publicly to clients. Used to encrypt data that only the matching private key can decrypt, and to verify the server's digital signatures.

#### The TLS 1.3 / 1.2 Handshake Step-by-Step
```
Client                                                   Server (NGINX)
  |                                                            |
  | 1. ClientHello (TLS Version, Supported Ciphers, SNI)       |
  |----------------------------------------------------------->|
  |                                                            |
  | 2. ServerHello (Selected Cipher Suite, Server Random)      |
  | 3. Certificate (Server's X.509 Public Certificate)         |
  | 4. ServerKeyExchange (ECDHE Ephemeral Parameters)          |
  | 5. ServerHelloDone                                         |
  |<-----------------------------------------------------------|
  |                                                            |
  | 6. ClientKeyExchange (ECDHE Client Parameters)             |
  | 7. ChangeCipherSpec & Encrypted Finished                   |
  |----------------------------------------------------------->|
  |                                                            |
  | 8. ChangeCipherSpec & Encrypted Finished                   |
  |<-----------------------------------------------------------|
  |                                                            |
  | ===== SECURE ENCRYPTED APPLICATION DATA (AES-GCM) =====    |
  | <----------------- Symmetric Traffic --------------------> |
```

#### What is SNI (Server Name Indication)?
**SNI** is a TLS extension where the client specifies the hostname it intends to connect to inside the initial `ClientHello` packet (before the TLS handshake is completed). This enables a single NGINX edge instance on one IP address to serve multiple independent domains (`app.team1.test`, `api.team1.test`) with completely different certificates.

---

### 3.4 Packet Filtering & Firewall Isolation (macOS PF)

#### What is a Firewall?
A firewall is a network security system that monitors and controls incoming and outgoing network traffic based on predetermined security rules.

#### Stateless vs. Stateful Packet Inspection (SPI)
- **Stateless Firewall**: Inspects packets in complete isolation based solely on static header values (Source IP, Destination IP, Port). It does not track connection context.
- **Stateful Firewall (`keep state` in macOS PF)**: Maintains a dynamic state table of active TCP/UDP sessions. When an outbound connection is permitted, return traffic belonging to that exact established session is automatically allowed without requiring an explicit inbound rule.

#### How macOS `pf` (Packet Filter) Works in our Setup:
macOS incorporates OpenBSD's `pf` engine. Our isolation rules:
```pf
# 1. Allow loopback traffic to pass freely
set skip on lo0

# 2. Allow Edge Proxy IP to access backend port 3001
pass in quick proto tcp from 10.7.27.66 to any port 3001 keep state

# 3. Block all other inbound attempts on port 3001 with an immediate TCP RST
block return-rst in quick proto tcp from any to any port 3001
```

#### Why `block return-rst` instead of `block drop`?
- `block drop`: Silently discards the TCP SYN packet. The client hangs and waits until its connection timeout expires (typically 30–60 seconds).
- `block return-rst`: Sends an immediate TCP Reset (`RST-ACK`) flag back to the client. This informs the client immediately that the port is closed/rejected, preventing connection hanging and simplifying debugging.

#### The Loopback (`lo0`) Quirk:
When testing `curl http://10.7.27.154:3002` locally from Mac 4, the operating system routes the packet through the loopback interface (`lo0`) rather than the physical Wi-Fi interface (`en0`). Because our rule contains `set skip on lo0`, local requests succeed, whereas external requests from other Macs hit `en0` and are rejected by PF.

---

### 3.5 Load Balancing Algorithms & Health Check Mechanisms

#### Common Load Balancing Algorithms:
1. **Round-Robin (Used in our project)**: Requests are distributed sequentially and evenly across available upstream servers (1 -> A, 2 -> B, 3 -> A, 4 -> B).
2. **Least Connections (`least_conn`)**: Directs traffic to the backend server with the lowest number of active concurrent TCP connections. Ideal for long-lived transactions.
3. **IP Hash (`ip_hash`)**: Hashes the client's IPv4 address to consistently map a specific client to the same backend server, ensuring session persistence without shared session stores.

#### Passive vs. Active Health Checks:
- **Active Health Checks**: The proxy periodically generates synthetic probes (e.g., `GET /health` every 2 seconds). If a backend fails consecutive probes, it is marked down. (Standard NGINX open-source does not include active health checks without third-party modules or NGINX Plus).
- **Passive Health Checks (Configured in our project)**: NGINX evaluates real client transactions as they occur:
  - `max_fails=1`: If a single request fails or times out, NGINX marks the server unavailable.
  - `fail_timeout=5s`: NGINX keeps the failed server out of rotation for 5 seconds before attempting to send traffic to it again.
  - `proxy_connect_timeout 2s`: Limits TCP connection establishment waiting time to 2 seconds.
  - `proxy_next_upstream error timeout http_502 http_503`: If the active backend returns an error or timeout, NGINX transparently replays that exact request to the secondary backend in real-time, preventing the client from ever seeing a failure.

---

### 3.6 Cloud & Enterprise Infrastructure Parallels

When answering viva questions, drawing direct parallels between our physical multi-Mac setup and cloud enterprise architectures (AWS/GCP/Azure) demonstrates senior-level understanding:

| On-Prem / Our 4-Mac Project | AWS Cloud Equivalent | Industry Function / Architectural Purpose |
|:---|:---|:---|
| **Mac 1 / Mac 4 (`dnsmasq`)** | **Amazon Route 53** | Authoritative DNS, health-checked DNS failover, private hosted zones |
| **Mac 2 (NGINX Edge Proxy)** | **Application Load Balancer (ALB) / CloudFront** | Layer 7 routing, TLS termination, SSL offload, request distribution |
| **Mac 3 / Mac 4 (Express Apps)** | **Amazon EC2 / ECS / EKS** | Compute instances running containerized backend application workloads |
| **macOS `pf` Firewall** | **Security Groups & Network ACLs** | Stateful instance-level isolation (Security Groups) & stateless subnet firewalls (NACLs) |
| **Wi-Fi Subnet (`10.7.x.x/24`)** | **Virtual Private Cloud (VPC)** | Isolated logical network space with defined CIDR blocks |
| **Standby Edge on Mac 3** | **Multi-AZ Hot Standby / Disaster Recovery** | High-availability active-passive failover across availability zones |

#### Key Cloud Concepts Explained:
- **Security Groups vs. Network ACLs (NACLs)**:
  - *Security Group*: Operates at the virtual NIC/instance level, is **stateful** (return traffic is automatically allowed), evaluates all rules before making a decision, and only supports allow rules. (Directly matches our macOS `pf` stateful implementation).
  - *Network ACL*: Operates at the subnet boundary, is **stateless** (inbound and outbound rules must be explicitly defined), and processes rules in strict numerical order.
- **Route Table**: A set of routing rules determining where network traffic from subnets or gateways is directed (e.g., `0.0.0.0/0 -> igw-xxx`).
- **Internet Gateway (IGW)**: A horizontally scaled, redundant VPC component that enables communication between instances in public subnets and the internet via NAT and routing.
- **Virtual Machine (VM / EC2) vs. Physical Bare Metal**:
  - A *Virtual Machine* runs on top of a hypervisor (Type 1 bare-metal like KVM/ESXi or Type 2 like VirtualBox) that abstracts hardware into virtual vCPUs, RAM, and virtual disks.
  - *Bare Metal (Our Project)*: Applications execute directly on the host operating system kernel and physical hardware, removing virtualization overhead and hypervisor abstraction layers.

---

### 3.7 Transport Layer Deep Dive: TCP Sockets, States & HTTP Headers

#### What is a Socket Pair?
A network socket is an endpoint of a two-way communication link. Every TCP connection is uniquely identified by a 4-tuple **Socket Pair**:
$$\text{Socket Pair} = (\text{Source IP}, \text{Source Port}, \text{Destination IP}, \text{Destination Port})$$

#### The TCP 3-Way Handshake & 4-Way Teardown:
```
TCP 3-Way Handshake (Connection Establishment):
Client                               Server
  | ----- SYN (Seq=x) -------------> | (Client enters SYN_SENT)
  | <---- SYN-ACK (Seq=y, Ack=x+1) - | (Server enters SYN_RCVD)
  | ----- ACK (Ack=y+1) -----------> | (Both enter ESTABLISHED)

TCP 4-Way Teardown (Connection Termination):
  | ----- FIN (Seq=u) -------------> | (Client enters FIN_WAIT_1)
  | <---- ACK (Ack=u+1) ------------ | (Server enters CLOSE_WAIT; Client enters FIN_WAIT_2)
  | <---- FIN (Seq=v) -------------- | (Server enters LAST_ACK)
  | ----- ACK (Ack=v+1) -----------> | (Client enters TIME_WAIT; Server enters CLOSED)
```

#### Key HTTP/1.1 Headers Implemented:
- `Cache-Control: max-age=60`: Informs client caches that the response is fresh for 60 seconds.
- `ETag` (Entity Tag): A cryptographic hash or version identifier representing the specific content of a resource.
- `If-None-Match`: A conditional request header sent by the client. If the server's current resource ETag matches the client's, the server returns `HTTP 304 Not Modified` with zero response body, drastically cutting network utilization.

---

## 4. Tough Viva Follow-Up Questions & Model Answers

### Q1: "Why did you use a 30-second TTL in Phase 2 instead of the standard 86400 seconds?"
> **Model Answer**: "A high TTL like 86,400 seconds (24 hours) is great for reducing DNS query volume for static sites. However, in an architecture where we perform planned maintenance, edge migrations (Extension E), or disaster recovery cutovers, clients with a 24-hour cache will continue sending traffic to the old or dead IP address. Setting `local-ttl=30` balances reducing DNS overhead with allowing records to propagate within 30 seconds during an operational cutover."

### Q2: "What is the Single Point of Failure (SPOF) in your Phase 2 architecture, and how did you resolve it?"
> **Model Answer**: "In Phase 1, both the Primary DNS (Mac 1) and Edge Reverse Proxy (Mac 2) were SPOFs. In Phase 2, we resolved the DNS SPOF by introducing a Secondary DNS resolver on Mac 4 (Extension A). We mitigated the Edge SPOF by configuring a Hot Standby Edge on Mac 3 with synchronized certificates (Extension E), which can be cut over seamlessly via DNS. In an enterprise cloud production environment, we would eliminate the edge SPOF dynamically using VRRP/Keepalived (Virtual IP takeover), AWS Anycast Route 53 routing, or an AWS Multi-AZ Application Load Balancer."

### Q3: "What happens at the packet level if a client tries to access Backend A on port 3001 directly?"
> **Model Answer**: "Because macOS `pf` firewall is active with `block return-rst in quick proto tcp from any to any port 3001`, the client's initial `TCP SYN` packet reaches Mac 3's network interface. The PF packet filter intercepts the packet before it reaches the socket listen queue of the Node.js process. Instead of dropping it silently, PF immediately crafts and returns a `TCP RST-ACK` packet to the client. The client's operating system receives the RST and immediately terminates the socket with `ECONNREFUSED` ('Connection refused')."

### Q4: "If Backend A crashes, why doesn't the user see an HTTP 502 Bad Gateway?"
> **Model Answer**: "In default NGINX setups, the client receives a 502 because the upstream connection fails. In our hardened configuration (`nginx-phase2.conf`), we configured `proxy_next_upstream error timeout http_502 http_503;` alongside `proxy_connect_timeout 2s;`. When NGINX attempts to forward the client's request to Backend A and gets a connection refused or timeout, it does not close the client connection. Instead, it immediately and transparently replays the exact same HTTP request to Backend B, returning a valid `200 OK` response to the client with `X-Backend: B`."

### Q5: "What is the difference between Layer 4 and Layer 7 load balancing? Which one did you implement?"
> **Model Answer**: "Layer 4 load balancing operates at the Transport layer (TCP/UDP). It routes packets based purely on IP addresses and ports without decrypting or inspecting application payload data. Layer 7 load balancing operates at the Application layer. We implemented Layer 7 reverse proxying using NGINX: it terminates TLS, parses the HTTP headers and URIs, can inspect cookies, injects reverse proxy headers (`X-Forwarded-For`), and evaluates HTTP response status codes for intelligent retry logic."

### Q6: "Why can Mac 4 curl its own port 3002 locally when the firewall is active, but other Macs are blocked?"
> **Model Answer**: "When an application on Mac 4 connects to its own IP (`10.7.27.154`), the Darwin XNU kernel routes the packets internally through the loopback pseudo-interface (`lo0`) rather than the physical wireless interface (`en0`). Our PF firewall rules explicitly state `set skip on lo0` to ensure local inter-process communication remains unhindered. External connections from Mac 1, 2, or 3 traverse `en0`, where the inbound firewall rule `block return-rst in quick proto tcp from any to any port 3002` actively matches and blocks them."

---

## 5. Pre-Flight Verification Checklist Before the Final Presentation

Complete this checklist 15 minutes before the faculty evaluation to ensure zero surprises on demo day.

```
+-----------------------------------------------------------------------------------------+
|                                PRE-FLIGHT READINESS CHECK                               |
+-----------------------------------------------------------------------------------------+
| [ ] Step 1: Verify Wi-Fi network and confirm all 4 laptops are on the same subnet.      |
| [ ] Step 2: Run dynamic IP sync (`./scripts/update-ips.sh`).                            |
| [ ] Step 3: Run ICMP Ping Matrix (All nodes must ping all other nodes).                 |
| [ ] Step 4: Verify required listening ports on all 4 Macs.                              |
| [ ] Step 5: Test DNS resolution against Primary and Backup servers.                     |
| [ ] Step 6: Execute Phase 1 health check (`./scripts/verify-phase1.sh`).                 |
| [ ] Step 7: Verify Packet Filter firewall state on Mac 3 and Mac 4.                     |
+-----------------------------------------------------------------------------------------+
```

### Exact Terminal Commands for Pre-Flight Checks:

#### 1. Synchronize Dynamic IPs Across All Configs (On Mac 4 or Any Mac)
```bash
./scripts/update-ips.sh
git pull   # (Run git pull on Macs 1, 2, and 3 so all configs match)
```

#### 2. Ping Matrix Verification (Run from Client / Mac 4)
```bash
source config/network.env
ping -c 2 $MAC1_IP && ping -c 2 $MAC2_IP && ping -c 2 $MAC3_IP
```
*Expected Result*: `0.0% packet loss` across all three targets.

#### 3. Listening Ports Audit
- **Mac 1 (Manas)**: `sudo lsof -i :53` (Verify `dnsmasq` is listening on UDP/TCP 53)
- **Mac 2 (Anant)**: `sudo lsof -i :80 -i :443` (Verify NGINX is listening on 80 and 443)
- **Mac 3 (Akhil)**: `lsof -i :3001` (Verify Node.js is listening on 3001)
- **Mac 4 (Darain)**: `lsof -i :3002 && sudo lsof -i :53` (Verify Node.js on 3002 and backup `dnsmasq` on 53)

#### 4. DNS Resolution Verification
```bash
source config/network.env
dig @$MAC1_IP app.team1.test +short   # Should return Mac 2 IP
dig @$MAC4_IP app.team1.test +short   # Should return Mac 2 IP
```

#### 5. Automated Pre-Flight Health Script
```bash
./scripts/verify-phase1.sh
```
*Expected Result*: All 6 Phase 1 health checks pass with `[PASS]`.

---

## 6. Faculty Ingested Error Guide & Live Fault-Injection Playbook

During the viva and final evaluation, professors will deliberately ask you to break things to test whether your architecture actually recovers and whether you understand the underlying networking mechanics.

Use these scripted procedures to handle any faculty request flawlessly.

---

### Challenge 1: "Shut down 1 backend right now and show that traffic still works."

- **What the Professor Expects**: Proof of high availability, automated load balancer failover, and zero user-facing downtime.
- **Action on Mac 3 (Akhil)**:
  ```bash
  # Stop Backend A
  pkill -f "node.*3001" || killall node
  ```
- **Action on Mac 4 (Syed Darain / Client)**:
  Run the automated HA test loop immediately:
  ```bash
  ./scripts/test-ha-failover.sh
  ```
  Or run manually:
  ```bash
  for i in {1..6}; do
    curl -k -s -I https://app.team1.test/api/status | grep -E "HTTP/|X-Backend"
  done
  ```
- **What Appears on the Screen**:
  ```http
  HTTP/1.1 200 OK
  X-Backend: B
  HTTP/1.1 200 OK
  X-Backend: B
  HTTP/1.1 200 OK
  X-Backend: B
  ```
- **Explanation to Give Faculty**:
  > *"Sir, Backend A is completely down. As you can see, 100% of incoming requests are immediately served by Backend B with `HTTP 200 OK`. NGINX's passive health check detected the connection failure on port 3001, and through our `proxy_next_upstream` directive, it instantly replayed the in-flight request to Backend B without returning a single `502 Bad Gateway` error to the client."*
- **Recovery Procedure**:
  ```bash
  # On Mac 3 (Akhil)
  cd /Users/akhilsharma/Documents/ComputerNetworks---ADAM/backend-a
  npm start
  ```
  *Re-run the curl loop: traffic immediately resumes 50/50 round-robin alternation between `X-Backend: A` and `X-Backend: B`.*

---

### Challenge 2: "Is the backend accessible directly, or only through NGINX? Prove it."

- **What the Professor Expects**: Verification of Layer 4 Service Isolation and defense-in-depth security.
- **The Live Demonstration**:
  1. **Direct Connection Attempt (Bypassing Edge)**:
     From Mac 1 or Mac 4, attempt to curl Backend A directly:
     ```bash
     source config/network.env
     curl -m 2 http://$MAC3_IP:3001/api/status
     ```
     *Output*:
     ```text
     curl: (7) Failed to connect to 10.7.24.241 port 3001: Connection refused
     ```
  2. **Connection Through Edge**:
     ```bash
     curl -k -s https://app.team1.test/api/status
     ```
     *Output*: `HTTP 200 OK` (Served successfully!)
- **Explanation to Give Faculty**:
  > *"Sir, our architecture enforces defense-in-depth. Using macOS Packet Filter (`pf`), we have applied kernel-level firewall rules on Mac 3 and Mac 4. Any direct connection to port 3001 or 3002 originating from any host other than the Edge Proxy IP (`$MAC2_IP`) is actively rejected with a TCP RST. Clients cannot bypass our Edge security, TLS termination, or logging."*

---

### Challenge 3: "Kill the Primary DNS server. Does the entire system go down?"

- **What the Professor Expects**: Proof of DNS redundancy and multi-nameserver resolver failover.
- **Action on Mac 1 (Manas)**:
  ```bash
  sudo pkill dnsmasq
  ```
- **Action on Mac 4 (Syed Darain / Client)**:
  Run the automated Backup DNS test:
  ```bash
  ./scripts/test-backup-dns.sh
  ```
  Or test directly against the Backup DNS server:
  ```bash
  source config/network.env
  dig @$MAC4_IP app.team1.test +short
  curl -k -s -I https://app.team1.test/api/status | grep "HTTP/"
  ```
- **Explanation to Give Faculty**:
  > *"Sir, although the Primary DNS on Mac 1 was terminated, our client network stack is configured with dual nameservers (`$MAC1_IP` and `$MAC4_IP`). When the client resolver encountered a timeout querying Mac 1, it automatically fell back to the secondary resolver running on Mac 4, resolving the domain without service interruption."*
- **Recovery Procedure**:
  ```bash
  # On Mac 1 (Manas)
  sudo dnsmasq -C $(pwd)/config/dnsmasq/dnsmasq-phase2-primary.conf -d
  ```

---

### Challenge 4: "What happens if BOTH backends are shut down?"

- **What the Professor Expects**: Understanding of HTTP status codes and reverse proxy error semantics.
- **Action**:
  - Stop Backend A on Mac 3 (`Ctrl+C` or `pkill -f 3001`).
  - Stop Backend B on Mac 4 (`Ctrl+C` or `pkill -f 3002`).
- **Client Execution**:
  ```bash
  curl -k -s -I https://app.team1.test/api/status
  ```
- **Output**:
  ```http
  HTTP/1.1 502 Bad Gateway
  Server: nginx/1.27.x
  ```
- **Explanation to Give Faculty**:
  > *"Sir, NGINX is an Application Layer reverse proxy. When both upstream servers fail to respond, NGINX cannot establish a valid TCP connection with any member of the upstream pool. In compliance with RFC 9110, NGINX returns `502 Bad Gateway`, indicating that the proxy received an invalid response (or connection refusal) from the inbound gateway servers."*
- **Recovery**: Restart both backends; subsequent curls return `200 OK` within 5 seconds (`fail_timeout` expiration).

---

### Challenge 5: "Demonstrate Edge Migration / Hot Standby Cutover."

- **What the Professor Expects**: Understanding of disaster recovery, DNS propagation, and hot standby proxying.
- **Action**:
  1. Start Standby NGINX on Mac 3 (Akhil):
     ```bash
     sudo nginx -c $(pwd)/config/nginx/nginx-standby.conf
     ```
  2. Run the migration script on Mac 4:
     ```bash
     ./scripts/test-edge-migration.sh
     ```
  3. Observe the response headers transition to:
     ```http
     HTTP/1.1 200 OK
     X-Edge-Server: standby-edge-mac3
     ```
- **Explanation to Give Faculty**:
  > *"Sir, Mac 3 operates as a pre-warmed hot-standby edge proxy. We updated the DNS A record to point to Mac 3. Because our DNS TTL was tuned to 30 seconds (Extension B), the new record propagated quickly, cutting over client traffic seamlessly with no dropped sessions."*

---

### 🚨 Emergency Live Troubleshooting Matrix (If Something Goes Wrong)

| Symptom on Demo Day | Root Cause | Instant Fix Command |
|:---|:---|:---|
| **`curl: (6) Could not resolve host: app.team1.test`** | Stale macOS DNS cache or `dnsmasq` stopped | Run: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`<br>Check Mac 1: `sudo lsof -i :53` |
| **`curl: (35) SSL: certificate verify failed`** | Self-signed certificate not trusted by curl | Use `curl -k` (insecure mode) or install CA: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/rootCA.crt` |
| **`502 Bad Gateway` when backends should be up** | Wrong IP in `config/nginx/nginx-phase2.conf` | Check IP with `ifconfig en0`, edit `config/network.env`, run `./scripts/update-ips.sh`, and reload NGINX (`sudo nginx -s reload`). |
| **Backend direct access is NOT blocked** | Firewall rules not loaded in `pf` | On Mac 3 or 4 run: `sudo ./scripts/apply-firewall.sh`<br>Verify active state: `sudo pfctl -sr` |
| **`kevent() reported that connect() failed (61: Connection refused)`** | Backend Express server crashed or not started | On Mac 3: `cd backend-a && npm start`<br>On Mac 4: `cd backend-b && npm start` |
| **Wi-Fi IP changed unexpectedly** | College Wi-Fi DHCP lease renewal | Run `./scripts/update-ips.sh`, enter new IPs, git commit/push, and run `git pull` on all laptops. |
