# Phase 1 Demo Video: Script and Tasks

**Target length: 4:35** (hard limit 5:00). Each part is planned a little under its time limit, so there's room for slow commands.

| Part | Content | Planned | Limit |
| ---- | ------- | ------- | ----- |
| 1 | Team intro + setup flow | 0:00 – 1:45 | 2:00 |
| 2 | How the configuration works | 1:45 – 3:35 | 2:00 |
| 3 | Failure demonstration (Section 5 / D3) | 3:35 – 4:35 | 1:00 |

Every command on screen is run for real with `demo/demo.sh` (it types the command at human speed, then runs it). Nothing is staged.

**Roles**

| Person | Mac | IP | Records | Speaks in |
| ------ | --- | -- | ------- | --------- |
| Manas Selukar (2401010259) | Mac 1, DNS | `10.7.17.68` | DNS clips, LAN check | 1B, 1F, 2A, 3A |
| Anant Singh (2401010067) | Mac 2, nginx edge | `10.7.21.52` | nginx clips | 1C, 2B, 2C, 3D |
| Akhil Sharma (2401020084) | Mac 3, Backend A | `10.7.24.127` | Backend A clips | 1D, 2D, 3B |
| Syed Darain Qamar (2401010472) | Mac 4, Backend B + **client** | `10.7.13.20` | Backend B clips, all client clips, **final edit** | 1A, 1E, 2E, 2F, 3C |

Darain's Mac acts as the client for HTTPS, load balancing, caching and failures, because it already uses Manas's DNS.

---

## 0. Before recording (everyone, ~10 min)

1. **Same network.** All four Macs on the same Wi-Fi. Each person runs `ipconfig getifaddr en0` and confirms their IP matches the table above. If an IP has changed, tell Anant so he can update the nginx upstream, and tell Darain so the docs can be updated.
2. **Latest repo.** `git pull`, then `chmod +x demo/demo.sh scripts/*.sh`.
3. **Terminal look.** Terminal → Settings → Profiles: pick a dark profile ("Pro" or "Homebrew") and set the font to **20 pt**. Make the window about 110 × 30 so text is readable in a video.
4. **Clean screen.** Turn on Do Not Disturb (Control Centre → Focus) and close Slack, WhatsApp, mail and other browser tabs. Hide the Dock if it covers the terminal.
5. **Client checks (Darain only):**
   - DNS points at Manas: `scutil --dns | grep nameserver` should list `10.7.17.68`.
   - The certificate is trusted: `curl -sI https://app.team1.test/ | head -1` should print `HTTP/1.1 200 OK` **without** `-k`. If it fails, add `config/certificates/app.team1.test.crt` to Keychain Access → System and set it to "Always Trust".
6. **Recording tool.** Press `Cmd+Shift+5`, choose **Record Selected Portion** and draw it around the terminal. Options → Microphone: **None**. The voiceover is recorded separately.
7. **File naming.** Save each clip as `<clip-id>-<name>.mov`, e.g. `2B-anant.mov`. Upload all clips to the shared drive folder `video-clips/`.

Record every clip **2–3 times** and keep the best one. Leave about 1 second of still screen at the start and end of each clip for clean cuts.

---

## Part 1: Team intro + setup flow (0:00 – 1:45)

### 1A · 0:00 – 0:10 · Title + topology · Darain
**Screen:** Open `docs/Topology Diagram.jpeg` full-screen in Preview. Hold for 10 s and move the cursor slowly from Client → DNS → Edge → Backends.
**Voiceover (Darain):**
> "This is Team 1's Phase 1 project, a private network service platform. A client resolves our private domain through our own DNS, connects over HTTPS to an nginx edge, and the edge load-balances across two backends."

### 1B · 0:10 – 0:27 · Manas, DNS server
**Screen (Manas's Mac):**
```bash
ipconfig getifaddr en0
sudo brew services list | grep dnsmasq
```
**Voiceover (Manas):**
> "I'm Manas Selukar, 2401010259. My Mac, 10.7.17.68, is the private DNS server. dnsmasq is running here and answers for app.team1.test."

### 1C · 0:27 – 0:44 · Anant, nginx edge
**Screen (Anant's Mac):** Use whatever command Anant normally uses to start nginx (e.g. `sudo brew services start nginx` or `sudo nginx`), then:
```bash
ipconfig getifaddr en0
sudo lsof -iTCP:443 -sTCP:LISTEN
```
**Voiceover (Anant):**
> "I'm Anant Singh, 2401010067. My Mac, 10.7.21.52, is the edge. nginx listens on port 443, terminates TLS, and forwards requests to the two backends."

### 1D · 0:44 – 1:01 · Akhil, Backend A
**Screen (Akhil's Mac):**
```bash
./scripts/start-backend-a.sh
```
Let it print the LAN IP and "Backend A running…". **Leave it running** for the rest of the recording.
**Voiceover (Akhil):**
> "I'm Akhil Sharma, 2401020084. My Mac, 10.7.24.127, runs Backend A, an Express API on port 3001."

### 1E · 1:01 – 1:18 · Darain, Backend B
**Screen (Darain's Mac):**
```bash
./scripts/start-backend-b.sh
```
Let it print the LAN IP and "Backend B running…". **Leave it running** in this window and open a **second Terminal window** for every client clip after this one.
**Voiceover (Darain):**
> "I'm Syed Darain Qamar, 2401010472. My Mac, 10.7.13.20, runs Backend B on port 3002. Both backends return the same API but label themselves A or B."

### 1F · 1:18 – 1:45 · LAN verification · Manas
**Screen (Manas's Mac):**
```bash
./demo/demo.sh 2
```
This runs `ifconfig en0`, then pings the edge and both backends. *Editor: speed up the middle of the pings 1.5× if the clip runs past 27 s.*
**Voiceover (Manas):**
> "Before any services, we confirm the LAN itself. All four machines are on the same private 10.7 network, and each one replies to ping from the DNS server, so layer-3 connectivity is in place."

---

## Part 2: How the configuration works (1:45 – 3:35)

### 2A · 1:45 – 2:10 · DNS configuration · Manas
**Screen (Manas's Mac):**
```bash
./demo/demo.sh 3
```
This shows the dnsmasq status, the four config lines (`address=`, `listen-address`, `bind-interfaces`), `dig +short` for app and api, then the full `dig`.
**Voiceover (Manas):**
> "The two address lines map app and api.team1.test to the edge, 10.7.21.52. listen-address and bind-interfaces make dnsmasq answer only on localhost and the LAN interface. dig confirms the answer, and the SERVER line shows it came from 10.7.17.68 on port 53."

### 2B · 2:10 – 2:38 · nginx configuration · Anant
**Screen (Anant's Mac):**
```bash
./demo/demo.sh 4
```
This shows the `upstream backend_servers` block, then the `listen 443 ssl`, `server_name app.team1.test` and `proxy_pass` lines, then `sudo nginx -t`.
**Voiceover (Anant):**
> "The upstream block lists both backends: Akhil on 3001 and Darain on 3002. With no weights set, nginx uses round-robin. The server block listens on 443 with SSL for app.team1.test, uses our certificate, and proxies everything to the upstream. max_fails and proxy_next_upstream make it skip a dead backend quickly. nginx -t confirms the syntax is valid."

### 2C · 2:38 – 2:53 · HTTPS · Darain records, Anant speaks
**Screen (Darain's client window):**
```bash
./demo/demo.sh 5
```
This runs `curl -v https://app.team1.test/` with **no `-k`**. *Editor: hold or zoom on the lines `Connected to app.team1.test (10.7.21.52) port 443`, `TLSv1.3`, `SSL certificate verify ok` and `HTTP/1.1 200 OK`.*
**Voiceover (Anant):**
> "From the client, curl connects to 10.7.21.52 on port 443, negotiates TLS 1.3, and verifies our certificate against the trusted CA. Only then does the HTTP request go through, and we get 200 OK."

### 2D · 2:53 – 3:05 · Backend A · Akhil
**Screen (Akhil's Mac):** Open `backends/backend-a/server.js` in VS Code for about 4 s with the `X-Backend` and `Cache-Control` lines visible. Then, in a second terminal (not the one running the server):
```bash
./demo/demo.sh 6a
```
**Voiceover (Akhil):**
> "Backend A sets an X-Backend header of A, and on the status endpoint a 60-second Cache-Control. Called directly on 3001, it returns its JSON."

### 2E · 3:05 – 3:17 · Backend B · Darain
**Screen (Darain's Mac):** `backends/backend-b/server.js` in VS Code for about 4 s, then in the client window:
```bash
./demo/demo.sh 7a
```
**Voiceover (Darain):**
> "Backend B is identical but labels itself B and also reports the server name and a timestamp. Here it is answering directly on 3002."

### 2F · 3:17 – 3:35 · Load balancing + caching · Darain
**Screen (Darain's client window):**
```bash
./demo/demo.sh 8
./demo/demo.sh 9
```
Scene 8 sends 6 requests to `https://app.team1.test/` and shows the alternating `X-Backend` header. Scene 9 runs `curl -I` on `/api/status` and shows `Cache-Control: max-age=60` and an `ETag`.
**Voiceover (Darain):**
> "Six requests to the same domain alternate A, B, A, B: round-robin at the edge. The headers show Cache-Control max-age 60 and an ETag, so clients can cache the status response and revalidate it."

---

## Part 3: Failure demonstration, Section 5 / D3 (3:35 – 4:35)

Record this part **last**, in this exact order, because it stops services. Coordinate on a call so each person acts on cue.

### 3A · 3:35 – 3:48 · Wrong DNS server · Darain records, Manas speaks
**Screen (Darain's client window):**
```bash
./demo/demo.sh f1
```
This asks our DNS (returns `10.7.21.52`), then asks Google's `8.8.8.8` (returns `status: NXDOMAIN`).
**Voiceover (Manas):**
> "Failure one: wrong DNS server. Our resolver returns the edge IP, but a public resolver like 8.8.8.8 has never heard of team1.test and returns NXDOMAIN. The network works, but the name can't be resolved."

### 3B · 3:48 – 4:05 · Backend A down · Akhil + Darain
1. **Akhil** records 3 s of his server terminal, presses **Ctrl+C**, and the server stops (clip `3B-akhil.mov`).
2. **Darain** then runs this in the client window:
   ```bash
   ./demo/demo.sh f2
   ```
   All 4 requests should show `X-Backend: B`.

**Voiceover (Akhil):**
> "Failure two: I stop Backend A. The edge marks it as failed and sends every request to Backend B. Users still get a response, with no long timeout."

### 3C · 4:05 – 4:20 · Both backends down · Darain
1. Darain presses **Ctrl+C** in the Backend B window (record it, 3 s).
2. In the client window:
   ```bash
   ./demo/demo.sh f3
   ```
   Expect `HTTP/1.1 502 Bad Gateway`. *If it shows anything else, keep the real output and tell the team. Don't re-stage it.*

**Voiceover (Darain):**
> "Failure three: both backends stopped. DNS still resolves and the edge still completes TLS, but nginx has no healthy upstream, so it returns 502 Bad Gateway."

### 3D · 4:20 – 4:35 · Wrong destination port · Darain records, Anant speaks
**Screen (Darain's client window):**
```bash
./demo/demo.sh f4
```
Shows `curl: (7) Failed to connect to app.team1.test port 8443 … Couldn't connect to server`.
**Voiceover (Anant):**
> "Failure four: wrong port. DNS resolves fine, but nothing listens on 8443, so the TCP connection is refused. Every layer has to be right for the request to succeed. That's our Phase 1 system."

**After recording:** Akhil and Darain restart their backends with the start scripts.

---

## Editing (Darain)

1. **iMovie** → New Movie. Drop the clips in order: 1A → 1F, 2A → 2F, 3A → 3D.
2. **Trim** dead time (typing pauses, long pings) so each clip fits its time slot. Use **speed 1.5×** only on waiting parts, never on output the viewer needs to read.
3. **Titles:** add a small lower-third at the start of each part ("Part 1 — Team & Setup", etc.) and on each person's first clip (name, roll number, role, IP).
4. **Zoom:** for 2C (TLS lines), 2F (alternating headers) and 3C (502), crop or zoom so the key line fills the frame for about 2 s.
5. **Voiceover:** each person records their lines on their phone or Mac (Voice Memos, quiet room) and sends `voice-<clip-id>-<name>.m4a`. Drop each recording under its clip. If a recording runs long, trim pauses rather than speeding up the voice.
6. **Check the length:** the final timeline must be **under 5:00**. Target 4:35.
7. Export: File → Share → File → 1080p, high quality.

## If something goes wrong while recording

| Problem | Fix |
| ------- | --- |
| `dig` returns nothing on the client | Client DNS isn't `10.7.17.68`. Fix it in System Settings → Network → Wi-Fi → Details → DNS. |
| `curl` without `-k` fails with a certificate error | The certificate isn't trusted on that Mac. See step 0.5. |
| Load-balancing loop shows only A or only B | One backend is down or its IP has changed. Check `ipconfig getifaddr en0` on that Mac and the nginx upstream. |
| 502 when everything should work | A backend isn't running, or the macOS firewall is blocking `node`. Allow it in System Settings → Network → Firewall. |
| An IP changed on the day | Update `config/nginx/nginx.conf` on Anant's Mac, reload nginx (`sudo nginx -s reload`), and re-record any clip that shows the old IP. |
