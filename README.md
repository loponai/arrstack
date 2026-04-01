# Tom Spark's ARR Stack

One-command automated media server with VPN protection. Sonarr, Radarr, Prowlarr, qBittorrent, Gluetun, Jellyfin, and more.

**Full video tutorial:** [YouTube Link Coming Soon]

## What You Get

| Service | Port | Purpose |
|---------|------|---------|
| Gluetun | — | VPN tunnel with kill switch |
| qBittorrent | 8080 | Torrent client (VPN protected) |
| Prowlarr | 9696 | Indexer manager (VPN protected) |
| FlareSolverr | 8191 | Cloudflare bypass (VPN protected) |
| Radarr | 7878 | Movie automation |
| Sonarr | 8989 | TV show automation |
| Lidarr | 8686 | Music automation |
| Bazarr | 6767 | Subtitle automation |
| Jellyfin | 8096 | Media server / streaming |
| Jellyseerr | 5055 | Netflix-like request UI |

All download traffic routes through Gluetun's VPN tunnel. If the VPN drops, all traffic stops — zero leaks. The deunhealth container auto-restarts services that become unhealthy.

## Quick Start

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect
```

### 2. Clone this repo

```bash
git clone https://github.com/loponai/arrstack.git
cd arrstack
```

### 3. Create folder structure

```bash
sudo bash setup-folders.sh
```

This creates:
```
/data/
├── torrents/     ← qBittorrent downloads here
│   ├── movies/
│   ├── tv/
│   └── music/
└── media/        ← Radarr/Sonarr organize files here (Jellyfin reads from here)
    ├── movies/
    ├── tv/
    └── music/
```

> **Hard links:** Both folders MUST be on the same drive/filesystem. Radarr and Sonarr create hard links (not copies) — the file appears in both locations but only uses disk space once.

### 4. Configure your VPN

```bash
cp .env.example .env
nano .env
```

Fill in your VPN provider and credentials. See [VPN Setup Guides](#vpn-setup-guides) below.

### 5. Launch

```bash
docker compose up -d
```

### 6. Verify everything is working

```bash
bash test-stack.sh
```

This runs a full health check — Docker status, VPN connection, IP leak test, service accessibility, hard link support, and folder permissions. If anything is wrong, it tells you exactly what to fix.

You can also check manually:
```bash
# Check Gluetun's IP (should be VPN, not your real IP)
docker exec gluetun wget -qO- ifconfig.me

# qBittorrent shares Gluetun's network, so the above proves both are tunneled.
docker exec qbittorrent wget -qO- ifconfig.me

# Check health status of all containers
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### 7. Configure services

Open each service in your browser at `http://YOUR-SERVER-IP:PORT` and follow the video tutorial for step-by-step configuration.

**Quick reference:**
- **qBittorrent** (`:8080`) — Get temp password: `docker logs qbittorrent 2>&1 | grep "temporary password"`
- **Prowlarr** (`:9696`) — Add indexers, connect to Radarr/Sonarr
- **Radarr** (`:7878`) — Root folder: `/data/media/movies`, download client category: `movies`
- **Sonarr** (`:8989`) — Root folder: `/data/media/tv`, download client category: `tv`
- **Jellyfin** (`:8096`) — Add libraries: `/data/media/movies`, `/data/media/tv`, `/data/media/music`
- **Jellyseerr** (`:5055`) — Connect to Jellyfin, Radarr, and Sonarr

**Internal Docker IPs — use these when connecting services to each other (NOT localhost):**

| IP | Service |
|----|---------|
| `172.39.0.2` | Gluetun (also qBittorrent, Prowlarr, FlareSolverr) |
| `172.39.0.3` | Radarr |
| `172.39.0.4` | Sonarr |
| `172.39.0.5` | Lidarr |
| `172.39.0.6` | Bazarr |
| `172.39.0.7` | Jellyfin |
| `172.39.0.8` | Jellyseerr |

These IPs are the same for everyone — they're hardcoded in the docker-compose file.

**Common connections:**
- Radarr/Sonarr → Download Client → qBittorrent: host `172.39.0.2`, port `8080`
- Prowlarr → Apps → Radarr: server `http://172.39.0.3:7878`
- Prowlarr → Apps → Sonarr: server `http://172.39.0.4:8989`
- Prowlarr → Apps → Prowlarr Server: `http://172.39.0.2:9696`
- Jellyseerr → Radarr: host `172.39.0.3`, port `7878`
- Jellyseerr → Sonarr: host `172.39.0.4`, port `8989`
- Jellyseerr → Jellyfin: host `172.39.0.7`, port `8096`

**Important Radarr/Sonarr settings:**
- Media Management → Show Advanced → **Use Hardlinks instead of Copy** → must be ON
- Media Management → **Rename Movies/Episodes** → recommended ON

## VPN Setup Guides

### Surfshark (Recommended)
The best value for torrenting — cheapest long-term plans, fast WireGuard speeds, and easy setup with Gluetun. [Get Surfshark](https://surfshark.com/friend/tomspark)

1. Go to [Surfshark Manual Setup](https://my.surfshark.com/vpn/manual-setup/main)
2. Select **WireGuard** and get your credentials (private key + address)
3. In your `.env`:
```
VPN_SERVICE_PROVIDER=surfshark
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=your_key_here
WIREGUARD_ADDRESSES=10.14.0.2/16
SERVER_COUNTRIES=United States
```

> The `.env.example` file is pre-configured for Surfshark. Just paste your private key and you're good to go.

### NordVPN
1. Go to [NordVPN Manual Setup](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
2. Select **NordLynx** (WireGuard) and generate a private key
3. In your `.env`:
```
VPN_SERVICE_PROVIDER=nordvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=your_key_here
WIREGUARD_ADDRESSES=10.5.0.2/16
SERVER_COUNTRIES=United States
```

### ProtonVPN
1. Go to [ProtonVPN WireGuard Config](https://account.protonvpn.com/) → Downloads → WireGuard
2. Generate a config file, open it, copy `PrivateKey` and `Address`
3. In your `.env`:
```
VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=your_key_here
WIREGUARD_ADDRESSES=10.2.0.2/32
SERVER_COUNTRIES=United States
VPN_PORT_FORWARDING=on
```

### AirVPN
1. Go to [AirVPN Config Generator](https://airvpn.org/) → Client Area → Config Generator
2. Select Linux → WireGuard → pick server → Generate
3. In your `.env`:
```
VPN_SERVICE_PROVIDER=airvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=your_key_here
WIREGUARD_PUBLIC_KEY=server_public_key
WIREGUARD_PRESHARED_KEY=your_preshared_key
WIREGUARD_ADDRESSES=your_ip/32
FIREWALL_VPN_INPUT_PORTS=your_port
VPN_PORT_FORWARDING=on
```

### Other Providers
Gluetun supports 30+ providers. Check the [full provider list](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers).

## Updating

```bash
cd arrstack
docker compose pull
docker compose up -d
```

## Remote Access with Tailscale (Optional)

Want to access Jellyfin, Jellyseerr, or any service from outside your home? [Tailscale](https://tailscale.com/) creates a private network between your devices — no port forwarding, no exposing anything to the public internet.

**On your server:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**On your phone/laptop/TV:**
1. Install Tailscale from your app store
2. Sign in with the same account

**Access your services from anywhere:**
```
http://YOUR-TAILSCALE-IP:8096    ← Jellyfin
http://YOUR-TAILSCALE-IP:5055    ← Jellyseerr
http://YOUR-TAILSCALE-IP:7878    ← Radarr
http://YOUR-TAILSCALE-IP:8989    ← Sonarr
```

Find your Tailscale IP with `tailscale ip -4` on the server.

Tailscale is free for personal use (up to 100 devices). Everything is encrypted with WireGuard — nobody can see your traffic, not even Tailscale.

> **Do NOT expose Jellyfin directly to the internet** (no port forwarding on your router). Use Tailscale or a reverse proxy instead. Direct exposure is a security risk.

## Troubleshooting

**Gluetun unhealthy / won't connect:**
- Double-check VPN credentials in `.env` — these are NOT your login email/password
- Try removing the gluetun folder and restarting: `rm -rf gluetun && docker compose up -d`
- Check logs: `docker logs gluetun`

**qBittorrent can't connect:**
- Make sure Gluetun is healthy: `docker ps` (should show "healthy")
- Check qBit is using VPN: `docker exec gluetun wget -qO- ifconfig.me`
- In qBittorrent settings → Advanced → set Network Interface to `tun0`

**Hard links not working (files copying instead):**
- Both `/data/torrents` and `/data/media` must be on the same filesystem
- Check Radarr/Sonarr → Settings → Media Management → "Use Hardlinks" is checked
- Verify with: `ls -i /data/torrents/movies/yourfile` and `ls -i /data/media/movies/YourMovie/yourfile` — inode numbers should match

**Permission errors:**
- Run `id` and make sure PUID/PGID in `.env` match your user
- Re-run: `sudo chown -R $(id -u):$(id -g) /data`

## Credits

Built by [Tom Spark](https://youtube.com/@tomspark) following [Trash Guides](https://trash-guides.info/) and [Servarr Wiki](https://wiki.servarr.com/) best practices.

Uses [Gluetun](https://github.com/qdm12/gluetun) for VPN, [LinuxServer.io](https://linuxserver.io) container images, and [Jellyseerr](https://github.com/Fallenbagel/jellyseerr) for the request system.
