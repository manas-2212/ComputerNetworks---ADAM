# Backend B

Backend B is one of the two application servers behind the NGINX edge. NGINX load-balances HTTPS traffic for `app.team1.test` round-robin between Backend A and Backend B.

| Item       | Value                     |
| ---------- | ------------------------- |
| Owner      | Darain                    |
| Host IP    | `10.7.13.20`              |
| Port       | `3002`                    |
| Bind addr  | `0.0.0.0` (all interfaces) |
| Runtime    | Node.js + Express 5       |
| Entry file | `server.js`               |

## Where it sits in the network

```text
CLIENT ──DNS──▶ Manas (10.7.17.68)  app.team1.test → 10.7.21.52
   │
   └──HTTPS :443──▶ NGINX edge, Anant (10.7.21.52)
                        ├──HTTP──▶ Backend A, Akhil  (10.7.4.37:3001)
                        └──HTTP──▶ Backend B, Darain (10.7.13.20:3002)   ← this service
```

TLS ends at NGINX. NGINX talks to Backend B over plain HTTP inside the LAN.

## Endpoints

### `GET /`

Basic check that the service is up.

```json
{
  "backend": "B",
  "message": "Backend B is running",
  "port": 3002
}
```

### `GET /api/status`

Status endpoint used to test load balancing and caching.

```json
{
  "backend": "B",
  "status": "ok",
  "server": "Darain",
  "timestamp": "2026-10-05T10:00:00.000Z"
}
```

### Response headers

| Header          | Value        | Purpose                                                                     |
| --------------- | ------------ | --------------------------------------------------------------------------- |
| `X-Backend`     | `B`          | Shows which backend served the request, so round-robin can be verified      |
| `Cache-Control` | `max-age=60` | Only on `/api/status`. Lets NGINX and the client cache the response for 60 s |
| `ETag`          | (auto)       | Added by Express, so conditional requests can return `304 Not Modified`     |

## Running it

### Requirements

- Node.js 18 or newer
- npm

### Using the start script (recommended)

From the repository root:

```bash
./scripts/start-backend-b.sh
```

The script:

1. checks that Node.js and npm are installed
2. runs `npm install` if `node_modules` is missing
3. stops with an error if port 3002 is already in use
4. prints this machine's LAN IP so you can check it matches `10.7.13.20`
5. starts `server.js`

If you get a permission error, make the script executable first:

```bash
chmod +x scripts/start-backend-b.sh
```

### Manually

```bash
cd backends/backend-b
npm install
node server.js
```

Expected output:

```text
Backend B running on http://0.0.0.0:3002
```

Press `Ctrl+C` to stop the server.

## Testing

### On the Backend B machine

```bash
curl -i http://localhost:3002/
curl -i http://localhost:3002/api/status
```

### From another machine on the LAN

This checks that the port is reachable, which NGINX needs:

```bash
curl -i http://10.7.13.20:3002/api/status
```

### Through the full stack (DNS → NGINX → backend)

```bash
curl -i https://app.team1.test/api/status
```

Run this a few times. The `X-Backend` header and the `"backend"` field should switch between `A` and `B`.

## Troubleshooting

| Problem | Likely cause / fix |
| ------- | ------------------ |
| `EADDRINUSE: address already in use :::3002` | Another process is using port 3002. Find it with `lsof -i :3002`, then stop it. |
| Works on `localhost` but not from other machines | The macOS firewall is blocking Node. Allow incoming connections for `node` in System Settings → Network → Firewall. Also check the machine is on the same LAN. |
| NGINX returns `502 Bad Gateway` for B | Backend B is not running, or the IP changed. Check with `ipconfig getifaddr en0` and update the NGINX upstream if it is no longer `10.7.13.20`. |
| `Cannot find module 'express'` | Dependencies are not installed. Run `npm install` in this folder. |
