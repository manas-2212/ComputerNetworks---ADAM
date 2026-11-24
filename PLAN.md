# Phase 2 Master Plan & Chronological Execution Runbook

**Course Project**: Computer Networks — Private Network Service Platform  
**Team**: Team Adam (Team 1)  
**Team Roster & Roles**:
- **Akhil Sharma** (2401020084) — **Mac 3** (Backend Server A & Standby Edge)
- **Syed Darain Qamar** (2401010472) — **Mac 4** (Backend Server B, Backup DNS & Client Lead)
- **Anant Singh** (2401010067) — **Mac 2** (Edge NGINX Reverse Proxy & Load Balancer)
- **Manas Selukar** (2401020259) — **Mac 1** (Primary DNS Server)

---

## 🗺️ Master Chronological Execution Timeline

Services **must never be started in random order**. In computer networks, downstream destinations and proxies must exist before traffic flows. Follow this strict sequence:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ STAGE 0: All Members ──> IP Discovery, Wi-Fi Connection & Configuration Sync          │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: Akhil (Mac 3) & Darain (Mac 4) ──> Start Backend Servers A (:3001) & B (:3002)│
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ STAGE 2: Anant (Mac 2) ──> Start & Reload Edge NGINX Proxy (Needs live backends)       │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: Manas (Mac 1) & Darain (Mac 4) ──> Start Primary & Secondary DNS Resolvers    │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: Darain (Mac 4) ──> Run Pre-Flight Phase 1 Check & Phase 2 Extension Tests     │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Part 1: Chronological Setup & Startup Sequence

### Stage 0: All Members — IP Discovery & Config Sync
> **Goal**: Synchronize any newly assigned Wi-Fi IP addresses so zero config mismatches occur.

1. **Everyone connects to the same private Wi-Fi / Hotspot**.
2. **Each member runs** in their terminal:
   ```bash
   ipconfig getifaddr en0
   ```
   *(If blank, run `ipconfig getifaddr en1`).*
3. **Record the 4 IPs**:
   - Manas (Mac 1, Primary DNS): `MAC1_IP`
   - Anant (Mac 2, Edge NGINX): `MAC2_IP`
   - Akhil (Mac 3, Backend A): `MAC3_IP`
   - Darain (Mac 4, Backend B/DNS): `MAC4_IP`
4. **Sync all configs in 5 seconds (Interactive Prompt + Auto-Git Push)**:
   One member (e.g. Darain) runs:
   ```bash
   ./scripts/update-ips.sh
   ```
   - You **do not need to manually edit any files** beforehand!
   - The script will prompt you on screen to enter each person's IP one by one.
   - It automatically updates `config/network.env`, dnsmasq configs, nginx configs, and firewall rules.
   - At the end, it will ask: `Would you like to automatically commit and push these changes to Git? (y/n) [y]:`
   - Press **`y` (or Enter)** $\rightarrow$ it will automatically `git add`, `commit`, and `git push` to your repository!
   - Then simply tell the other 3 teammates to run:
     ```bash
     git pull
     ```
   *(Alternatively, if anyone is working offline, each person can simply run `./scripts/update-ips.sh` locally on their own Mac and enter the same 4 IPs).*

---

### Stage 1: Akhil & Darain — Start Backends First (The Destination)
> **Goal**: Bring up the destination HTTP REST APIs on ports 3001 and 3002 before NGINX tries to reach them.

1. **Akhil (Mac 3 — Backend A)**:
   In Terminal Window 1:
   ```bash
   ./scripts/start-backend-a.sh
   ```
   *Expected Output*: `Starting Backend A on 0.0.0.0:3001 ... Reachable at http://<MAC3_IP>:3001`  
   *(Leave this terminal window running!)*

2. **Darain (Mac 4 — Backend B)**:
   In Terminal Window 1:
   ```bash
   ./scripts/start-backend-b.sh
   ```
   *Expected Output*: `Starting Backend B on 0.0.0.0:3002 ... Reachable at http://<MAC4_IP>:3002`  
   *(Leave this terminal window running!)*

---

### Stage 2: Anant — Start Edge NGINX Second (The Reverse Proxy)
> **Goal**: Start NGINX and connect its upstream pool to the live Backends A & B.

1. **Anant (Mac 2 — Edge NGINX)**:
   In Terminal Window 1:
   ```bash
   # Test configuration syntax
   sudo nginx -t -c $(pwd)/config/nginx/nginx-phase2.conf

   # Start or reload NGINX with Phase 2 HA config
   sudo nginx -c $(pwd)/config/nginx/nginx-phase2.conf -s reload 2>/dev/null || sudo nginx -c $(pwd)/config/nginx/nginx-phase2.conf
   ```
2. **Verify NGINX is listening on port 443**:
   ```bash
   sudo lsof -iTCP:443 -sTCP:LISTEN
   ```
   *Expected Output*: Shows `nginx` worker processes listening on port 443.

---

### Stage 3: Manas & Darain — Start DNS Resolvers Third (The Directory)
> **Goal**: Provide primary and redundant private domain resolution (`app.team1.test` $\rightarrow$ Anant's IP).

1. **Manas (Mac 1 — Primary DNS)**:
   In Terminal Window 1:
   ```bash
   sudo brew services stop dnsmasq 2>/dev/null || true
   sudo dnsmasq -d -C "$(pwd)/config/dnsmasq/dnsmasq-phase2-primary.conf"
   ```
   *(Or via Homebrew: `sudo cp config/dnsmasq/dnsmasq-phase2-primary.conf /opt/homebrew/etc/dnsmasq.conf && sudo brew services restart dnsmasq`)*  
   *Expected Output*: `started, version ... cache size 150`, listening on `127.0.0.1` and `<MAC1_IP>`.  
   *(Leave this terminal window running!)*

2. **Darain (Mac 4 — Backup DNS)**:
   In Terminal Window 2:
   ```bash
   sudo brew services stop dnsmasq 2>/dev/null || true
   sudo dnsmasq -d -C "$(pwd)/config/dnsmasq/dnsmasq-phase2-backup.conf"
   ```
   *Expected Output*: `started, version ... cache size 150`, listening on `127.0.0.1` and `<MAC4_IP>`.  
   *(Leave this terminal window running!)*

3. **Configure Client DNS**:
   On Mac 4 (and any other client test Mac):
   - Go to **System Settings $\rightarrow$ Network $\rightarrow$ Wi-Fi $\rightarrow$ Details $\rightarrow$ DNS**.
   - Add Nameserver 1: `<MAC1_IP>` (Manas - Primary)
   - Add Nameserver 2: `<MAC4_IP>` (Darain - Backup)
   - Click **OK** and **Apply**.

---

### Stage 4: Darain — Run Pre-Flight Health Check (Verify Phase 1)
> **Goal**: Confirm all Phase 1 protocols (DNS, TCP, TLS, Load Balancing, Caching) work 100% before starting Phase 2 demos.

* **Darain (Mac 4)**:
  In Terminal Window 3:
  ```bash
  ./scripts/verify-phase1.sh
  ```
  *Expected Output*:
  ```text
  [CHECK 1/6] Layer 3 LAN Ping Reachability: All nodes reachable.
  [CHECK 2/6] Local Role Service Status: PASSED.
  [CHECK 3/6] Direct Backend Service Responses: Backend A & B OK.
  [CHECK 4/6] DNS Resolution: app.team1.test -> MAC2_IP OK.
  [CHECK 5/6] HTTPS Access: HTTP 200 OK (Certificate Trusted).
  [CHECK 6/6] Load Balancing & Caching: X-Backend and Cache-Control headers verified.
  PRE-FLIGHT CHECK SUMMARY: 6 / 6 Passed. ALL SYSTEMS GO!
  ```

---

## ⚡ Part 2: Phase 2 Extensions Execution Sequence (Extensions A – F)

Once the system is running, execute and demonstrate the Phase 2 extensions in this exact sequential order:

---

### 1️⃣ Extension A: Backup DNS Resolver Failover
* **Actors**: Darain (Client & Backup) + Manas (Primary DNS).
* **Step-by-Step Sequence**:
  1. **Darain** runs the test script in Terminal 3:
     ```bash
     ./scripts/test-backup-dns.sh
     ```
  2. The script confirms both Primary (`MAC1_IP`) and Backup (`MAC4_IP`) resolve `app.team1.test`.
  3. The script pauses and prompts: *"Press Enter after stopping Primary DNS on Mac 1..."*
  4. **Manas** switches to Terminal 1 on Mac 1 and stops primary DNS:
     - Press **`Ctrl+C`** to kill `dnsmasq`.
  5. **Darain** presses **`Enter`** on Mac 4.
  6. **Result**: The client query automatically redirects to Backup DNS (`MAC4_IP`), resolving the IP with zero downtime!
  7. 📸 **TAKE SCREENSHOT NOW**:
     - Capture Darain's terminal showing `SUCCESS: Domain resolved via Backup DNS`.
     - Save in folder: `evidence/dns/`
     - File name: `evidence/dns/backup-dns-failover.png`
  8. **Manas** restarts primary DNS:
     ```bash
     sudo dnsmasq -d -C "$(pwd)/config/dnsmasq/dnsmasq-phase2-primary.conf"
     ```

---

### 2️⃣ Extension B: DNS TTL & Cache Invalidation
* **Actors**: Darain (Client, Mac 4) + Manas (DNS Server, Mac 1).
* **Concept**: TTL (Time-To-Live) tells the client operating system how many seconds to cache a DNS response before querying the server again. In production cutovers, clients don't see IP changes until their cache expires, unless manually flushed.
* **Step-by-Step Execution**:
  1. **Darain runs the interactive script on Mac 4**:
     ```bash
     ./scripts/test-ttl-caching.sh
     ```
     - *What it shows*: Prints the DNS answer section:
       `app.team1.test.   30   IN   A   <MAC2_IP>`
       Points out the `30` (TTL in seconds).
     - 📸 **TAKE SCREENSHOT 1**:
       - Capture the 30-second TTL in the ANSWER section.
       - Save in folder: `evidence/dns/`
       - File name: `evidence/dns/ttl-30s-countdown.png`
  2. **Manas changes the record on Mac 1**:
     - Manas opens `config/dnsmasq/dnsmasq-phase2-primary.conf`.
     - Changes `address=/app.team1.test/<MAC2_IP>` to `address=/app.team1.test/10.7.21.99`.
     - Reloads dnsmasq:
       ```bash
       sudo killall -HUP dnsmasq
       ```
  3. **Darain observes the caching effect**:
     - Darain presses Enter in the script.
     - The script queries the DNS server directly (`dig @<MAC1_IP>`), showing the DNS server already has the new IP `10.7.21.99`.
     - BUT it then queries macOS's local cache resolver (`dscacheutil`), showing that **macOS STILL returns the old IP `<MAC2_IP>`!**
  4. **Darain demonstrates manual cache flushing**:
     - Darain presses Enter in the script to run:
       ```bash
       sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
       ```
     - *Result*: **Now macOS instantly returns `10.7.21.99`!**
     - 📸 **TAKE SCREENSHOT 2**:
       - Capture the terminal output showing the cached old IP followed by the immediate cutover to `10.7.21.99` after flush.
       - Save in folder: `evidence/dns/`
       - File name: `evidence/dns/ttl-cache-and-flush.png`
  5. **Cleanup**:
     - Manas restores `<MAC2_IP>` in `config/dnsmasq/dnsmasq-phase2-primary.conf` and runs `sudo killall -HUP dnsmasq`.
     - Darain flushes cache once more.

---

### 3️⃣ Extension C: Service Isolation (Backend Firewall)
* **Actors**: Akhil (Backend A, Mac 3) + Darain (Backend B & Client, Mac 4).
* **Concept**: Clients must never communicate with backend database or application ports directly. All access must be mediated through the reverse proxy. macOS `pf` (Packet Filter) drops unauthorized direct connections at Layer 4.
* **Step-by-Step Sequence**:
  1. **Akhil & Darain activate the firewall on their backend machines**:
     - On Mac 3 (Akhil), run:
       ```bash
       sudo ./scripts/apply-firewall.sh
       ```
     - On Mac 4 (Darain), run:
       ```bash
       sudo ./scripts/apply-firewall.sh
       ```
     - 📸 **TAKE SCREENSHOT 1**:
       - Capture the terminal showing `sudo pfctl -sr` listing rules restricting ports 3001 & 3002 to `MAC2_IP`.
       - Save in folder: `evidence/firewall/`
       - File name: `evidence/firewall/pfctl-rules-active.png`
  2. **Darain runs the comprehensive service isolation test on Mac 4**:
     ```bash
     ./scripts/test-service-isolation.sh
     ```
  3. **Result**:
     - **Test 1 (Direct to Backend A, :3001)**: $\rightarrow$ **Connection Refused / Blocked!**
     - **Test 2 (Direct to Backend B, :3002)**: $\rightarrow$ **Connection Refused / Blocked!**
     - **Test 3 (Authorized Ingress via Edge Proxy)**: $\rightarrow$ **HTTP 200 OK!**
     - 📸 **TAKE SCREENSHOT 2**:
       - Capture Darain's terminal showing direct port access BLOCKED while Edge proxy access SUCCEEDS.
       - Save in folder: `evidence/firewall/`
       - File name: `evidence/firewall/backend-direct-access-blocked.png`
  4. **Rollback after demo**:
     - Akhil on Mac 3: `sudo ./scripts/rollback-firewall.sh`
     - Darain on Mac 4: `sudo ./scripts/rollback-firewall.sh`

---

### 4️⃣ Extension D: High-Availability Failover
* **Actors**: Darain (Client) + Akhil (Backend A) + Anant (Edge NGINX).
* **Step-by-Step Sequence**:
  1. **Anant** views live NGINX access logs in Terminal 2 on Mac 2:
     ```bash
     tail -f /opt/homebrew/var/log/nginx/access.log
     ```
  2. **Darain** starts the continuous loop of 10 requests:
     ```bash
     ./scripts/test-ha-failover.sh
     ```
     *Observe*: Initially requests alternate: `X-Backend: A`, `X-Backend: B`, `X-Backend: A`...
  3. **Akhil** kills Backend A on Mac 3 by pressing **`Ctrl+C`** in Terminal 1.
  4. **Result**: NGINX triggers `proxy_next_upstream` within 1 second! 100% of subsequent requests route to Backend B (`X-Backend: B`). **Zero HTTP 502 errors appear on the client!**
  5. 📸 **TAKE SCREENSHOT NOW**:
     - Capture Darain's terminal showing the loop cleanly transitioning 100% to Backend B without any 502 errors.
     - Save in folder: `evidence/failover/`
     - File name: `evidence/failover/backend-a-down-failover-to-b.png`
  6. **Akhil** restarts Backend A:
     ```bash
     ./scripts/start-backend-a.sh
     ```
  7. **Result**: NGINX automatically detects Backend A is healthy again and resumes round-robin balancing.

---

### 5️⃣ Extension E: Controlled Edge Migration (DNS Cutover)
* **Actors**: Akhil (Standby Edge, Mac 3) + Manas (DNS, Mac 1) + Darain (Client, Mac 4).
* **Step-by-Step Sequence**:
  1. **Akhil sets up SSL certificates on Mac 3** (One-command setup):
     ```bash
     sudo ./scripts/setup-standby-certs.sh
     ```
  2. **Akhil launches the Standby NGINX instance on Mac 3**:
     ```bash
     sudo nginx -c $(pwd)/config/nginx/nginx-standby.conf
     ```
  3. **Manas updates the primary DNS record on Mac 1**:
     In `config/dnsmasq/dnsmasq-phase2-primary.conf`, change:
     `address=/app.team1.test/<MAC2_IP>` to `address=/app.team1.test/<MAC3_IP>`  
     Reload dnsmasq:
     ```bash
     sudo killall -HUP dnsmasq
     ```
  4. **Darain runs the edge migration check on Mac 4**:
     ```bash
     ./scripts/test-edge-migration.sh
     ```
  5. **Result**: Client requests transition smoothly to Mac 3, displaying response header: `X-Edge-Proxy: nginx-standby-mac3`!
  6. 📸 **TAKE SCREENSHOT NOW**:
     - Capture Darain's terminal showing the response header `X-Edge-Proxy: nginx-standby-mac3`.
     - Save in folder: `evidence/cutover/`
     - File name: `evidence/cutover/standby-edge-cutover-header.png`
  7. **Cleanup**:
     - Manas restores `MAC2_IP` in dnsmasq and runs `sudo killall -HUP dnsmasq`.
     - Akhil stops standby nginx: `sudo nginx -c $(pwd)/config/nginx/nginx-standby.conf -s stop`.

---

### 6️⃣ Extension F: Faculty-Injected Fault Challenge
* **Actors**: Entire Team.
* **Step-by-Step Sequence**:
  1. The professor introduces a secret fault into one of the laptops.
  2. **Darain immediately runs**:
     ```bash
     ./scripts/diagnose-stack.sh
     ```
  3. **The team speaks out loud following the 4-Layer Diagnostic Protocol**:
     - *"Layer 1: Checking DNS resolution first..."*
     - *"Layer 2: Checking Layer 3 ICMP ping and Layer 4 TCP port 443..."*
     - *"Layer 3: Checking TLS handshake and certificate trust..."*
     - *"Layer 4: Checking Application layer and upstream backends..."*
  4. The tool pinpoints the exact broken layer and recommends the fix.
  5. 📸 **TAKE SCREENSHOT NOW**:
     - Capture the complete output of `diagnose-stack.sh` showing all 4 layers checked and the isolated fault.
     - Save in folder: `evidence/troubleshooting/`
     - File name: `evidence/troubleshooting/diagnose-stack-4layers.png`
  6. The responsible teammate applies the fix and re-runs `./scripts/diagnose-stack.sh` to prove full recovery.
     - *"Layer 2: Checking Layer 3 ICMP ping and Layer 4 TCP port 443..."* (Checks network & port availability).
     - *"Layer 3: Checking TLS handshake and certificate trust..."* (Checks SSL/TLS errors).
     - *"Layer 4: Checking Application layer and upstream backends..."* (Checks for 502 Bad Gateway or 504 Timeout).
  4. The tool pinpoints the exact broken layer and recommends the fix.
  5. The responsible teammate applies the fix and re-runs `./scripts/diagnose-stack.sh` to prove full recovery.

---

## 👥 Part 3: Individual Member Reference Cheat Sheets

Keep these commands handy for your specific laptop:

### 👤 Akhil Sharma (Mac 3)
* **Start Backend A**: `./scripts/start-backend-a.sh`
* **Apply Firewall**: `sudo ./scripts/apply-firewall.sh`
* **Rollback Firewall**: `sudo ./scripts/rollback-firewall.sh`
* **Start Standby Edge**: `sudo nginx -c $(pwd)/config/nginx/nginx-standby.conf`
* **Stop Standby Edge**: `sudo nginx -c $(pwd)/config/nginx/nginx-standby.conf -s stop`

### 👤 Syed Darain Qamar (Mac 4)
* **Start Backend B**: `./scripts/start-backend-b.sh`
* **Start Backup DNS**: `sudo dnsmasq -d -C "$(pwd)/config/dnsmasq/dnsmasq-phase2-backup.conf"`
* **Run Pre-Flight Check**: `./scripts/verify-phase1.sh`
* **Run All Tests**: `./scripts/test-backup-dns.sh`, `./scripts/test-service-isolation.sh`, `./scripts/test-ha-failover.sh`, `./scripts/test-ttl-caching.sh`, `./scripts/diagnose-stack.sh`

### 👤 Anant Singh (Mac 2)
* **Test NGINX Config**: `sudo nginx -t -c $(pwd)/config/nginx/nginx-phase2.conf`
* **Reload NGINX**: `sudo nginx -c $(pwd)/config/nginx/nginx-phase2.conf -s reload`
* **Watch Error Log**: `tail -f /opt/homebrew/var/log/nginx/error.log`

### 👤 Manas Selukar (Mac 1)
* **Start Primary DNS**: `sudo dnsmasq -d -C "$(pwd)/config/dnsmasq/dnsmasq-phase2-primary.conf"`
* **Reload DNS Config**: `sudo killall -HUP dnsmasq`
* **Query Local DNS**: `dig @127.0.0.1 app.team1.test`

---

## 🏆 Part 4: 11-Step Final Presentation Sequence

| # | Step | Speaker / Actor | Command / Visual Action |
|---|---|---|---|
| **1** | Topology & Roles | **Akhil** | Display `docs/architecture.md` diagram and explain the 4 machine roles. |
| **2** | LAN Connectivity | **Manas** | Ping all machines from Mac 1 (`ping -c 2 <MAC2_IP>`, `<MAC3_IP>`, `<MAC4_IP>`). |
| **3** | DNS Resolution | **Darain** | Run `dig app.team1.test` showing it resolves to Anant's IP (`MAC2_IP`). |
| **4** | HTTPS Access | **Darain** | Run `curl -v https://app.team1.test/` showing trusted TLS handshake (no `-k`). |
| **5** | Load Balancing | **Darain** | Run loop showing alternating `X-Backend: A` and `X-Backend: B`. |
| **6** | Wireshark Packet Proof | **Darain** | Open Wireshark pcap: point out DNS, TCP 3-way handshake, TLS Client/ServerHello. |
| **7** | HTTP Caching | **Darain** | Run `curl -I https://app.team1.test/api/status` showing `Cache-Control: max-age=60`. |
| **8** | HA Failover | **Akhil & Anant** | Akhil kills Backend A (`Ctrl+C`); Darain runs test loop showing 100% traffic to B without 502s. |
| **9** | Resilience Showcase | **Manas & Akhil** | Manas kills primary DNS $\rightarrow$ Backup DNS resolves; Akhil activates pf firewall $\rightarrow$ port 3001 blocked. |
| **10**| Faculty Fault Diagnosis | **Entire Team** | Run `./scripts/diagnose-stack.sh`; speak diagnosis layer-by-layer out loud. |
| **11**| Individual Viva | **Entire Team** | Each member answers individual viva questions from `docs/viva-prep.md`. |

---

## 📸 Part 5: Evidence Capture & File Naming Guide

To satisfy the **Evidence Folder** deliverable required by the course syllabus (Review 2 rubric), your team must save screenshots of all Phase 2 extensions into their respective topic folders inside `evidence/`.

---

### 📋 Phase 2 Evidence Master Index (By Category Folder)

#### 1. 🌐 DNS Resilience (`evidence/dns/`)
| Evidence File Name | Extension | What Must Be Visible in the Screenshot |
|---|---|---|
| `evidence/dns/backup-dns-failover.png` | **Ext A** (Backup DNS) | Output of `./scripts/test-backup-dns.sh` showing `SUCCESS: Domain resolved via Backup DNS` after primary DNS on Mac 1 was stopped. |
| `evidence/dns/ttl-30s-countdown.png` | **Ext B** (DNS TTL) | Output of `dig @<MAC1_IP> app.team1.test` showing the `30` second TTL in the `ANSWER SECTION`. |
| `evidence/dns/ttl-cache-and-flush.png` | **Ext B** (Cache Flush) | Terminal output of `./scripts/test-ttl-caching.sh` showing the client serving the old cached IP until flushed, then immediately returning `10.7.21.99`. |

#### 2. 🛡️ Firewall & Service Isolation (`evidence/firewall/`)
| Evidence File Name | Extension | What Must Be Visible in the Screenshot |
|---|---|---|
| `evidence/firewall/pfctl-rules-active.png` | **Ext C** (Firewall Rules) | Terminal on Mac 3 or Mac 4 showing `sudo pfctl -sr` with rules allowing ONLY `MAC2_IP` and blocking other incoming traffic on ports 3001 & 3002. |
| `evidence/firewall/backend-direct-access-blocked.png` | **Ext C** (Isolation Demo) | Output of `./scripts/test-service-isolation.sh` showing direct port 3001 & 3002 connections **REFUSED / BLOCKED**, while Edge proxy HTTPS access returns **HTTP 200 OK**. |

#### 3. 🔄 High Availability & Failover (`evidence/failover/`)
| Evidence File Name | Extension | What Must Be Visible in the Screenshot |
|---|---|---|
| `evidence/failover/backend-a-down-failover-to-b.png` | **Ext D** (HA Failover) | Output of `./scripts/test-ha-failover.sh` showing 100% of requests seamlessly routed to Backend B (`X-Backend: B`) when Backend A was killed, with **zero HTTP 502 errors**. |

#### 4. 🚀 Standby Edge Cutover (`evidence/cutover/`)
| Evidence File Name | Extension | What Must Be Visible in the Screenshot |
|---|---|---|
| `evidence/cutover/standby-edge-cutover-header.png` | **Ext E** (Edge Cutover) | Output of `./scripts/test-edge-migration.sh` showing the response header `X-Edge-Proxy: nginx-standby-mac3` after DNS cutover. |

#### 5. 🔍 Systematic Troubleshooting (`evidence/troubleshooting/`)
| Evidence File Name | Extension | What Must Be Visible in the Screenshot |
|---|---|---|
| `evidence/troubleshooting/diagnose-stack-4layers.png` | **Ext F** (Fault Challenge) | Complete execution output of `./scripts/diagnose-stack.sh` isolating an injected issue layer-by-layer (DNS, TCP, TLS, Upstream). |

---

### 💻 How to Take Clean Terminal Screenshots on macOS

1. On your Mac, click on the Terminal window you want to capture.
2. Press **`Cmd + Shift + 4`**, then press the **`Spacebar`**.
   - Your cursor will turn into a camera icon 📷.
   - Click the Terminal window.
3. macOS saves the screenshot directly to your **Desktop** (`~/Desktop/Screenshot <date>.png`).
4. Move and rename the screenshot into the project evidence subfolder:
   ```bash
   # Example:
   mv ~/Desktop/Screenshot*.png evidence/dns/backup-dns-failover.png
   ```

### 📤 Commit & Push All Evidence to Git
Once your screenshots are saved, push them to your repository:
```bash
git add evidence/
git commit -m "docs(evidence): add complete Phase 2 screenshot deliverables"
git push
```
All evidence is now archived, cleanly organized, and ready for your evaluator!
