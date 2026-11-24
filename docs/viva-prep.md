# Team Adam — Viva & Presentation Guide (Easy & Conversational)

> **Goal**: This guide explains our entire Computer Networks project in **simple, plain English**.  
> No complicated academic jargon! Use this to understand the concepts easily and speak confidently in front of the professor during the viva.

---

## Table of Contents
1. [The 30-Second Project Summary (Elevator Pitch)](#1-the-30-second-project-summary)
2. [What We Did in Phase 2 in Simple Words](#2-what-we-did-in-phase-2-in-simple-words)
3. [Who Did What? (Roles & Spoken Scripts)](#3-who-did-what-roles--spoken-scripts)
   - [Manas (Mac 1 — DNS Specialist)](#-manas-selukar-mac-1--dns-specialist)
   - [Anant (Mac 2 — NGINX & Load Balancer Lead)](#-anant-singh-mac-2--nginx--load-balancer-lead)
   - [Akhil (Mac 3 — Backend A & Firewall Lead)](#-akhil-sharma-mac-3--backend-a--firewall-lead)
   - [Darain (Mac 4 — Backend B, Backup DNS & Automation)](#-syed-darain-qamar-mac-4--backend-b-backup-dns--automation)
4. [Core Networking Concepts Explained Like You're 10](#4-core-networking-concepts-explained-simply)
   - [4.1 DNS & dnsmasq (The Phonebook)](#41-dns--dnsmasq-the-phonebook)
   - [4.2 NGINX & Reverse Proxy (The Receptionist / Bouncer)](#42-nginx--reverse-proxy-the-receptionist--bouncer)
   - [4.3 SSL/TLS Certificates (The Passport)](#43-ssltls-certificates-the-passport)
   - [4.4 Firewalls & macOS PF (The VIP Guest List)](#44-firewalls--macos-pf-the-vip-guest-list)
   - [4.5 Load Balancing & Failover (Two Cashiers at a Store)](#45-load-balancing--failover-two-cashiers-at-a-store)
   - [4.6 Cloud Networking Explained Simply (AWS Parallels)](#46-cloud-networking-explained-simply-aws-parallels)
   - [4.7 TCP Handshake & HTTP Headers](#47-tcp-handshake--http-headers)
5. [Common Tough Viva Questions & Simple 2-Sentence Answers](#5-common-tough-viva-questions--simple-answers)
6. [Pre-Flight Checklist: 5 Minutes Before Presentation](#6-pre-flight-checklist-5-minutes-before-presentation)
7. [Faculty Fault-Injection Guide: Exactly What to Do When Sir Asks to Break Things](#7-faculty-fault-injection-guide)

---

## 1. The 30-Second Project Summary

**If the professor asks: "What is this project about?"**

> *"Sir, we built a secure, high-availability web service running across 4 separate MacBooks over local Wi-Fi.  
> - **Mac 1** acts as our custom DNS server.  
> - **Mac 2** is an NGINX reverse proxy that terminates HTTPS and balances traffic.  
> - **Mac 3 and Mac 4** run our backend servers.  
> In Phase 2, we hardened the system: if a server crashes, traffic automatically switches with **zero downtime**; if someone tries to hack or access our backends directly, our **firewall blocks them immediately**; and if the primary DNS dies, our **backup DNS takes over** seamlessly."*

---

## 2. What We Did in Phase 2 in Simple Words

In **Phase 1**, we had a simple working website, but it was fragile:
- If Mac 1 or Mac 2 stopped working, the entire website died.
- Anyone on the Wi-Fi could bypass NGINX and talk directly to our backends on ports 3001 or 3002.
- If one backend crashed, users saw `502 Bad Gateway` errors.

In **Phase 2**, we fixed all of that by adding 5 resilience features:
1. **Backup DNS (Ext A)**: Added a second DNS server on Mac 4. If Mac 1 dies, Mac 4 answers DNS queries automatically.
2. **Short TTL (Ext B)**: Told devices only to remember DNS answers for 30 seconds, so we can change server IPs quickly without long delays.
3. **Firewall Isolation (Ext C)**: Locked down our backend ports (3001 and 3002) using macOS's built-in `pf` firewall. Only NGINX (Mac 2) is allowed in. Everyone else gets rejected.
4. **Zero-Downtime Failover (Ext D)**: Configured NGINX so that if Backend A dies mid-request, NGINX instantly sends that exact request to Backend B. The user never sees an error!
5. **Standby Edge (Ext E)**: Created a backup NGINX on Mac 3. If Mac 2 catches fire, we can switch the DNS to Mac 3 in 30 seconds.
6. **Smart Troubleshooting (Ext F)**: Wrote an automated script (`diagnose-stack.sh`) that tests the network layer by layer (Ping $\rightarrow$ Port $\rightarrow$ SSL $\rightarrow$ Webpage).

---

## 3. Who Did What? (Roles & Spoken Scripts)

```
[Mac 1 - Manas]             [Mac 2 - Anant]              [Mac 3 - Akhil]              [Mac 4 - Darain]
Primary DNS (dnsmasq)       Active Edge Proxy (NGINX)    Backend A (:3001)            Backend B (:3002)
Port: 53                    Ports: 80 & 443              Standby Edge (:443)          Backup DNS (:53)
Role: Name Resolution       Role: TLS & Load Balancer    Role: Backend + Firewall     Role: Backend + Automation
```

---

### 👤 Manas Selukar (Mac 1 — DNS Specialist)

- **What I Did**:
  - Configured `dnsmasq` so that typing `app.team1.test` points to Anant's IP (Mac 2).
  - Set `local-ttl=30` so that clients only cache the IP for 30 seconds.
  - Added upstream DNS forwarders (`1.1.1.1` and `8.8.8.8`) so normal internet still works.
  - Tested killing the DNS daemon to prove the client falls back to Darain's backup DNS on Mac 4.
- **Your Viva Spoken Script**:
  > *"Sir, I managed the Domain Name System on Mac 1 using `dnsmasq`. I created our custom local domain `app.team1.test`. I set the Time-To-Live (TTL) to 30 seconds so that if we move our servers, clients don't get stuck with old cached IPs. I also verified that when my server stops, the client automatically falls back to our secondary DNS on Mac 4."*

---

### 👤 Anant Singh (Mac 2 — NGINX & Load Balancer Lead)

- **What I Did**:
  - Configured NGINX to handle HTTPS securely on port 443 with our team's SSL certificate.
  - Set up HTTP-to-HTTPS redirect so any user on port 80 is forwarded to secure port 443.
  - Configured the load balancer to share traffic 50/50 between Backend A (Mac 3) and Backend B (Mac 4).
  - Set up **fast failover** (`proxy_next_upstream`): if Backend A dies, NGINX silently re-routes the request to Backend B in milliseconds with zero 502 errors.
- **Your Viva Spoken Script**:
  > *"Sir, I configured the NGINX reverse proxy on Mac 2. My machine acts as the front door. It terminates SSL/TLS so backends don't have to waste CPU on encryption. I configured round-robin load balancing between Backend A and Backend B. If one backend crashes, my NGINX detects it within 2 seconds and forwards the user's request to the other backend, so the user never sees an error."*

---

### 👤 Akhil Sharma (Mac 3 — Backend A & Firewall Lead)

- **What I Did**:
  - Ran Backend A using Node.js/Express on port 3001, returning `X-Backend: A`.
  - Configured macOS's `pf` firewall to **lock port 3001**: only Anant's NGINX (Mac 2) can connect. If anyone else on the Wi-Fi tries, the connection is instantly rejected with a TCP Reset (`RST`).
  - Set up a **Hot Standby Edge NGINX** on port 443 with copied SSL certificates, ready to take over if Mac 2 fails.
- **Your Viva Spoken Script**:
  > *"Sir, I hosted Backend A on port 3001 and enforced security isolation using macOS Packet Filter (`pf`). In a real company, backends should never be exposed to the public. My firewall only allows connections from Mac 2 (the edge proxy) and rejects everyone else. I also pre-warmed a standby NGINX proxy on my machine for disaster recovery."*

---

### 👤 Syed Darain Qamar (Mac 4 — Backend B, Backup DNS & Automation)

- **What I Did**:
  - Ran Backend B on port 3002, returning `X-Backend: B` and caching headers (`ETag`, `Cache-Control`).
  - Ran the **Secondary/Backup DNS server** on port 53 to protect against Mac 1 crashing.
  - Configured the `pf` firewall to protect port 3002 from direct external access.
  - Built the entire automated test and diagnostic suite: IP updater, Phase 1 verification, firewall toggles, HA failover test, and the 4-layer diagnostic script (`diagnose-stack.sh`).
- **Your Viva Spoken Script**:
  > *"Sir, I hosted Backend B on port 3002 with HTTP caching, and I ran the Secondary DNS server on port 53. I also wrote all our automation scripts: `update-ips.sh` to update everyone's changing Wi-Fi IPs in one click, `test-ha-failover.sh` to prove zero-downtime during backend crashes, and `diagnose-stack.sh` which checks the network bottom-up from Ping to Ports, SSL, and HTTP."*

---

## 4. Core Networking Concepts Explained Simply

Here is common knowledge that **every team member must understand**.

---

### 4.1 DNS & `dnsmasq` (The Phonebook)

- **What is DNS?**  
  Computers only understand numbers (IP addresses like `10.7.27.66`), but humans understand names (`app.team1.test`). DNS is like the **Contacts / Phonebook app** on your phone: you look up a name to get the phone number.
- **Why UDP instead of TCP for DNS?**  
  A DNS lookup is just one question and one short answer.
  - TCP requires a 3-way handshake before talking (slower).
  - UDP sends the question immediately in one packet (faster).
  - *Exception*: DNS uses TCP only if the answer is bigger than 512 bytes or for zone transfers between servers.
- **What is TTL (Time-To-Live)?**  
  TTL is an expiration timer on the answer. If TTL is 30 seconds, your computer remembers the IP for 30 seconds. After 30 seconds, it throws it away and asks the DNS server again.  
  - *High TTL (24 hours)*: Saves network traffic, but if your server changes IP, users can't reach you for 24 hours!
  - *Low TTL (30 seconds - Our project)*: Allows quick migrations and testing with no stale records.
- **What is `dnsmasq`?**  
  It is a small, lightweight DNS program for local networks that reads simple text files to answer domain queries.

---

### 4.2 NGINX & Reverse Proxy (The Receptionist / Bouncer)

```
Forward Proxy:
[You] --------> [Proxy (e.g. College VPN)] --------> [Google.com]
(Protects the client. The destination server doesn't know who you are.)

Reverse Proxy:
[Client] --------> [NGINX (Mac 2)] --------> [Backend A (Mac 3)]
                                   --------> [Backend B (Mac 4)]
(Protects the servers. The client thinks NGINX is the whole website!)
```

- **Forward Proxy vs Reverse Proxy**:
  - *Forward Proxy*: Sits in front of the **client** (like a VPN hiding your identity).
  - *Reverse Proxy (NGINX)*: Sits in front of the **servers** (like a hotel receptionist). Clients only talk to NGINX; NGINX fetches the data from the backends behind closed doors.
- **Why terminate TLS (HTTPS) at NGINX?**
  1. **CPU Savings**: Encrypting and decrypting HTTPS takes heavy math. Doing it once at the edge saves CPU on our backends.
  2. **One Certificate**: We only need to install the SSL certificate on NGINX, not on every backend.
  3. **Inspection**: NGINX can read the decrypted HTTP request to do smart load balancing.
- **What are Proxy Headers?**  
  When NGINX calls a backend, the backend sees NGINX's IP as the caller. So NGINX adds special headers:
  - `X-Real-IP`: The real user's IP.
  - `X-Forwarded-For`: The full list of IPs the request traveled through.
  - `Host`: The original domain name the user typed.

---

### 4.3 SSL/TLS Certificates (The Passport)

- **What is an SSL/TLS Certificate?**  
  It is a digital passport for a website. It proves two things:
  1. **Identity**: "I really am `app.team1.test`."
  2. **Encryption**: Gives the browser a Public Key so communication is scrambled and safe from eavesdroppers.
- **Public Key vs Private Key**:
  - **Public Key**: Like a padlock. Anyone can use it to lock (encrypt) a message.
  - **Private Key**: The only key that opens that padlock. Stored securely on Mac 2. Only NGINX can unlock (decrypt) the message.
- **What is a Certificate Authority (CA)?**  
  Like a government passport office. We created our own local Root CA to sign our certificate so macOS trusts it.
- **What is SNI (Server Name Indication)?**  
  In the first hello packet, the browser says: *"I want to talk to `app.team1.test`."* This allows one single NGINX server with one IP address to host 10 different websites with 10 different certificates.

---

### 4.4 Firewalls & macOS PF (The VIP Guest List)

- **What is a Firewall?**  
  A security filter running inside the operating system kernel that inspects every network packet and decides: **ALLOW or BLOCK**.
- **Stateful vs Stateless Firewall**:
  - *Stateless*: Looks at every single packet with no memory.
  - *Stateful (`keep state` in our PF)*: Remembers connections! Once an incoming connection is approved, the outgoing reply is automatically allowed back through.
- **Why `block return-rst` instead of `block drop`?**
  - `block drop`: Drops the packet silently into the trash. The client gets no reply and sits frozen waiting 60 seconds for a timeout.
  - `block return-rst`: Instantly slams the door and sends a TCP Reset (`RST`). The client gets an immediate `"Connection refused"` in 2 milliseconds. Clean and fast!
- **Why did `curl localhost:3002` work on Mac 4 even with the firewall on?**  
  Because when you curl your own machine, macOS routes the traffic through the **loopback interface (`lo0`)**, not the physical Wi-Fi card (`en0`). Our firewall rule says `set skip on lo0`, so internal laptop traffic is never blocked.

---

### 4.5 Load Balancing & Failover (Two Cashiers at a Store)

- **Round-Robin**:  
  Request 1 goes to Cashier A (Mac 3).  
  Request 2 goes to Cashier B (Mac 4).  
  Request 3 goes to Cashier A, and so on.
- **Passive Health Check (`max_fails=1 fail_timeout=5s`)**:  
  NGINX doesn't constantly spam health-check pings. Instead, it watches real user traffic. If a request to Backend A fails once, NGINX marks Backend A as "sick" and leaves it alone for 5 seconds.
- **Failover (`proxy_next_upstream`)**:  
  If NGINX knocks on Backend A's door and nobody answers, NGINX doesn't tell the user "Error 502". It immediately knocks on Backend B's door with the exact same request. The user gets a normal `200 OK` page and never notices anything was wrong!

---

### 4.6 Cloud Networking Explained Simply (AWS Parallels)

Professors love asking how your project maps to real-world cloud architectures (AWS / Azure):

| What We Built (Physical Macs) | AWS Cloud Equivalent | What It Does (In Simple Words) |
|:---|:---|:---|
| **Mac 1 & 4 (`dnsmasq`)** | **Amazon Route 53** | The cloud phonebook that resolves domain names. |
| **Mac 2 (NGINX Edge Proxy)** | **AWS Application Load Balancer (ALB)** | Terminates HTTPS and shares traffic between backends. |
| **Mac 3 & 4 (Express Apps)** | **Amazon EC2 / ECS** | Virtual compute servers running the backend code. |
| **macOS `pf` Firewall** | **Security Groups** | Virtual firewalls around each server allowing only specific ports/IPs. |
| **Local Wi-Fi Subnet (`10.7.x.x`)** | **Virtual Private Cloud (VPC)** | An isolated private network where your servers live. |
| **Standby Edge (Mac 3)** | **Disaster Recovery (DR) Standby** | A backup server in another zone ready if the main one fails. |

- **Security Group vs Network ACL (NACL)**:
  - *Security Group*: Lives at the **server level**, is **stateful** (return traffic is automatic). Just like our macOS `pf` firewall.
  - *Network ACL*: Lives at the **subnet boundary**, is **stateless** (must write rules for both incoming and outgoing).
- **Route Table**: The roadmap inside a network telling packets which way to go.
- **Internet Gateway (IGW)**: The doorway connecting your private VPC network to the public world-wide web.
- **Virtual Machine (EC2) vs Bare Metal**:
  - *VM / EC2*: Runs on a software slice of a physical server (hypervisor).
  - *Bare Metal (Our Project)*: Code runs directly on real physical hardware with no virtualization layers.

---

### 4.7 TCP Handshake & HTTP Headers

- **TCP 3-Way Handshake**:
  1. **SYN**: Client $\rightarrow$ *"Hey, can I connect?"*
  2. **SYN-ACK**: Server $\rightarrow$ *"Yes, I hear you! Here is my acknowledgment."*
  3. **ACK**: Client $\rightarrow$ *"Great, let's start talking!"*
- **What is a Socket Pair?**  
  Every TCP connection is defined by 4 numbers:  
  $$(\text{Client IP, Client Port, Server IP, Server Port})$$
- **HTTP Caching Headers**:
  - `Cache-Control: max-age=60`: Browser caches the response for 60 seconds.
  - `ETag`: A fingerprint hash of the webpage content.
  - `If-None-Match`: Client asks *"Has the page changed since I got this ETag?"* If no, server returns **`304 Not Modified`** without downloading the body again, saving Wi-Fi bandwidth!

---

## 5. Common Tough Viva Questions & Simple Answers

### Q1: "Why did you use a 30-second TTL instead of 1 day?"
> **Simple Answer**: *"Sir, if we use 24 hours, clients will remember old IPs for a full day. If our server IP changes or an edge node fails, users are stuck. A 30-second TTL gives us the agility to perform zero-downtime cutovers while still preventing unnecessary DNS query spam."*

### Q2: "What is the Single Point of Failure (SPOF) in your project?"
> **Simple Answer**: *"In Phase 1, Mac 2 (the NGINX Edge) was a SPOF. If Mac 2 died, everything died. In Phase 2, we solved this by pre-warming a Hot Standby Edge on Mac 3 and setting up a 30-second DNS cutover runbook."*

### Q3: "What happens when someone tries to connect to Backend A on port 3001 directly?"
> **Simple Answer**: *"Our macOS `pf` firewall catches the TCP SYN packet. Because the sender's IP is not Mac 2, the firewall immediately replies with a TCP Reset (`RST-ACK`). The client gets an instant `Connection refused` error."*

### Q4: "Why does the user not see a 502 Bad Gateway error when Backend A crashes?"
> **Simple Answer**: *"Because in NGINX we configured `proxy_next_upstream error timeout http_502`. When NGINX sees Backend A fail, it immediately retries the exact same request on Backend B before answering the client. The client gets a clean 200 OK."*

### Q5: "What is the difference between Layer 4 and Layer 7 load balancing?"
> **Simple Answer**: *"Layer 4 only looks at IP addresses and TCP ports—it doesn't understand URLs or HTTPS. Layer 7 (our NGINX) decrypts the HTTPS, reads headers, cookies, and URL paths, and can make smart decisions like retrying failed requests or routing `/api` differently."*

---

## 6. Pre-Flight Checklist (5 Minutes Before Presentation)

Follow these exact steps before calling the professor over:

1. **Check Everyone's Wi-Fi IPs**:
   ```bash
   # Run on Mac 4 (or any Mac)
   ./scripts/update-ips.sh
   # On all other Macs, run:
   git pull origin main
   ```
2. **Ping Matrix (Check all 4 Macs can talk)**:
   ```bash
   source config/network.env
   ping -c 2 $MAC1_IP && ping -c 2 $MAC2_IP && ping -c 2 $MAC3_IP
   ```
3. **Verify All Services are Running**:
   - Mac 1: `sudo lsof -i :53` (dnsmasq)
   - Mac 2: `sudo lsof -i :80 -i :443` (nginx)
   - Mac 3: `lsof -i :3001` (backend-a)
   - Mac 4: `lsof -i :3002 && sudo lsof -i :53` (backend-b & backup dnsmasq)
4. **Run the Automated Health Check**:
   ```bash
   ./scripts/verify-phase1.sh
   ```
   *(All 6 checks should show `[PASS]`!)*

---

## 7. Faculty Fault-Injection Guide

Here is your exact playbook when the professor asks you to break or test things live.

---

### Challenge 1: "Shut down 1 backend right now and show me what happens."

- **Step 1 (Akhil on Mac 3)**:
  Press `Ctrl + C` in the backend terminal, or run:
  ```bash
  killall node
  ```
- **Step 2 (Darain on Mac 4)**:
  Run our automated test script:
  ```bash
  ./scripts/test-ha-failover.sh
  ```
- **What Appears on the Screen**:
  ```text
  Request #1: Status = 200 | Served by: X-Backend: B
  Request #2: Status = 200 | Served by: X-Backend: B
  Request #3: Status = 200 | Served by: X-Backend: B
  ```
- **What to Say to Sir**:
  > *"Sir, Backend A is completely dead. As you can see, 100% of requests are now smoothly handled by Backend B with `HTTP 200 OK`. NGINX detected Backend A was down and transparently replayed the request to Backend B. The user never saw a single error!"*
- **How to Restore**:
  On Mac 3: `npm start`.  
  Run the curl again: requests immediately alternate 50/50 between Backend A and Backend B!

---

### Challenge 2: "Is the backend accessible directly, or only through NGINX? Prove it."

- **Step 1 (Bypass Attempt)**:
  From Mac 4 or Mac 1, try to call Backend A directly:
  ```bash
  source config/network.env
  curl -m 2 http://$MAC3_IP:3001/api/status
  ```
  *Result*:
  ```text
  curl: (7) Failed to connect: Connection refused
  ```
- **Step 2 (Legitimate Ingress Through NGINX)**:
  ```bash
  curl -k -s https://app.team1.test/api/status
  ```
  *Result*: `HTTP 200 OK` with JSON response!
- **What to Say to Sir**:
  > *"Sir, direct access is strictly blocked by our macOS `pf` firewall rules. Only the Edge Proxy IP is whitelisted. This prevents attackers on the LAN from bypassing our SSL termination, rate limits, and audit logs."*

---

### Challenge 3: "Kill the Primary DNS server. Does the website go down?"

- **Step 1 (Manas on Mac 1)**:
  ```bash
  sudo pkill dnsmasq
  ```
- **Step 2 (Darain on Mac 4)**:
  ```bash
  ./scripts/test-backup-dns.sh
  ```
- **What to Say to Sir**:
  > *"Sir, Primary DNS on Mac 1 is dead. But because our network config has two nameservers listed, the client automatically timed out on Mac 1 and queried our Backup DNS on Mac 4. The website resolves and opens without any problem."*
- **How to Restore**:
  On Mac 1: `sudo dnsmasq -C $(pwd)/config/dnsmasq/dnsmasq-phase2-primary.conf -d`

---

### Challenge 4: "What happens if BOTH backends are shut down?"

- **Step 1**: Kill Backend A on Mac 3 and Backend B on Mac 4.
- **Step 2**: Curl the website:
  ```bash
  curl -k -s -I https://app.team1.test/api/status
  ```
- **What Appears**: `HTTP/1.1 502 Bad Gateway`.
- **What to Say to Sir**:
  > *"Sir, NGINX is an application reverse proxy. When all backend instances are dead, NGINX has nobody to talk to. Following the standard HTTP protocol (RFC 9110), NGINX returns `502 Bad Gateway`, proving the failure is isolated to the upstream tier."*
- **How to Restore**: Start both backends (`npm start`); curls return `200 OK` within 5 seconds!
