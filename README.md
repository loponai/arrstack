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
| Seerr | 5055 | Netflix-like request UI |

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

### 6. Verify VPN is working

```bash
# Check Gluetun's IP (should be VPN, not your real IP)
docker exec gluetun wget -qO- ifconfig.me

# Check qBittorrent is tunneled
docker exec qbittorrent curl -s ifconfig.me

# Kill switch test (optional)
docker stop gluetun
docker exec qbittorrent curl -s --max-time 5 ifconfig.me  # Should fail/timeout
docker start gluetun
```

### 7. Configure services

Open each service in your browser at `http://YOUR-SERVER-IP:PORT` and follow the video tutorial for step-by-step configuration.

**Quick reference:**
- **qBittorrent** (`:8080`) — Get temp password: `docker logs qbittorrent 2>&1 | grep "temporary password"`
- **Prowlarr** (`:9696`) — Add indexers, connect to Radarr/Sonarr
- **Radarr** (`:7878`) — Root folder: `/data/media/movies`, download client category: `movies`
- **Sonarr** (`:8989`) — Root folder: `/data/media/tv`, download client category: `tv`
- **Jellyfin** (`:8096`) — Add libraries: `/data/media/movies`, `/data/media/tv`, `/data/media/music`
- **Seerr** (`:5055`) — Connect to Jellyfin, Radarr, and Sonarr

**Important Radarr/Sonarr settings:**
- Media Management → Show Advanced → **Use Hardlinks instead of Copy** → must be ON
- Media Management → **Rename Movies/Episodes** → recommended ON
- Download Client → qBittorrent host: `172.39.0.2` (Gluetun's IP), port: `8080`

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
WIREGUARD_ADDRESSES=
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

## Troubleshooting

**Gluetun unhealthy / won't connect:**
- Double-check VPN credentials in `.env` — these are NOT your login email/password
- Try removing the gluetun folder and restarting: `rm -rf gluetun && docker compose up -d`
- Check logs: `docker logs gluetun`

**qBittorrent can't connect:**
- Make sure Gluetun is healthy: `docker ps` (should show "healthy")
- Check qBit is using VPN: `docker exec qbittorrent curl -s ifconfig.me`
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

Uses [Gluetun](https://github.com/qdm12/gluetun) for VPN, [LinuxServer.io](https://linuxserver.io) container images, and [Seerr](https://github.com/seerr-team/seerr) for the request system.
