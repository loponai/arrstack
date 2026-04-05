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
| Seerr | 5055 | Netflix-like request UI (Overseerr/Jellyseerr successor) |

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
- **Prowlarr** (`:9696`) — Add indexers, connect to Radarr/Sonarr. If an indexer is blocked by Cloudflare, set up FlareSolverr as a proxy: Settings → Indexers → Add Proxy → FlareSolverr → host `http://localhost:8191` → give it a tag (e.g. `flaresolverr`). Then edit the blocked indexer and add the **same tag** so Prowlarr routes it through FlareSolverr.
- **Radarr** (`:7878`) — Root folder: `/data/media/movies`, download client category: `movies`
- **Sonarr** (`:8989`) — Root folder: `/data/media/tv`, download client category: `tv`
- **Jellyfin** (`:8096`) — Add libraries: `/data/media/movies`, `/data/media/tv`, `/data/media/music`. To watch, open `http://YOUR-SERVER-IP:8096` in a browser or use the Jellyfin app (available on Roku, Fire TV, Apple TV, Android TV, iOS, Android). Find your server IP by running `hostname -I` in the terminal. If watching remotely with Tailscale, use your Tailscale IP instead.
- **Seerr** (`:5055`) — Connect to Jellyfin, Radarr, and Sonarr. Seerr is the unified successor to Overseerr/Jellyseerr. If you previously ran Jellyseerr here, your existing config is migrated automatically on first start.

**Internal Docker IPs — use these when connecting services to each other (NOT localhost):**

| IP | Service |
|----|---------|
| `172.39.0.2` | Gluetun (also qBittorrent, Prowlarr, FlareSolverr) |
| `172.39.0.3` | Radarr |
| `172.39.0.4` | Sonarr |
| `172.39.0.5` | Lidarr |
| `172.39.0.6` | Bazarr |
| `172.39.0.7` | Jellyfin |
| `172.39.0.8` | Seerr |

These IPs are the same for everyone — they're hardcoded in the docker-compose file.

**Common connections:**
- Radarr/Sonarr → Download Client → qBittorrent: host `172.39.0.2`, port `8080`
- Prowlarr → Apps → Radarr: server `http://172.39.0.3:7878`
- Prowlarr → Apps → Sonarr: server `http://172.39.0.4:8989`
- Prowlarr → Apps → Prowlarr Server: `http://172.39.0.2:9696`
- Seerr → Radarr: host `172.39.0.3`, port `7878`
- Seerr → Sonarr: host `172.39.0.4`, port `8989`
- Seerr → Jellyfin: host `172.39.0.7`, port `8096`

**Important Radarr/Sonarr settings:**
- Media Management → Show Advanced → **Use Hardlinks instead of Copy** → must be ON
- Media Management → **Rename Movies/Episodes** → recommended ON

**Recommended quality profile (1080p baseline, 4K preferred):**

Go to Settings → Profiles and edit or create a profile:
1. Uncheck everything below 1080p (720p, 480p, etc.)
2. Check/enable everything from **HDTV-1080p** up through **Bluray-2160p**
3. Set **Cutoff** to `Bluray-1080p` — this is the minimum quality Radarr/Sonarr will be happy with
4. Set **Upgrade Until** to `Bluray-2160p` — it will automatically upgrade to 4K if one becomes available

This means it grabs a 1080p release right away so you can start watching, then silently upgrades to 4K later if it finds one.

## VPN Setup Guides

### Surfshark (Recommended)
The best value for torrenting — cheapest long-term plans, fast WireGuard speeds, and easy setup with Gluetun. [Get Surfshark](https://get.surfshark.net/aff_c?offer_id=1126&aff_id=9447&aff_sub=8amjxr)

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

## Starting and Stopping

**Start the stack:**
```bash
cd arrstack
docker compose up -d
```

**Stop the stack:**
```bash
cd arrstack
docker compose down
```

**Check status:**
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Auto-Start After Reboot

All containers are set to `restart: unless-stopped`, which means they automatically come back once Docker is running. You just need to make sure Docker itself starts when your computer boots up.

**Linux (dedicated server or VM):**

Run this once and you're done:
```bash
sudo systemctl enable docker
```

**Windows (running Docker inside WSL):**

WSL (Windows Subsystem for Linux) doesn't start Docker automatically when your PC boots. Here's how to fix that:

**Step 1:** Open your WSL terminal and run this command to edit the WSL config file:
```bash
sudo nano /etc/wsl.conf
```

**Step 2:** Your file might already have some lines in it (like `[boot]` or `[user]`). Look for a `[boot]` section. If it exists, add the `command=` line under it. If it doesn't exist, add both lines. It should look like this when you're done:
```ini
[boot]
command=service docker start
```

**Step 3:** Save the file by pressing `Ctrl+X`, then `Y`, then `Enter`.

**Step 4 (optional):** By default, WSL only starts when you open a terminal. If you want it to start automatically when Windows boots (so your stack is always running), do this:

1. Press `Win+R` on your keyboard
2. Type `shell:startup` and press Enter — this opens your Windows Startup folder
3. Right-click in the folder → New → Text Document
4. Name it `wsl.vbs` (make sure it ends in `.vbs`, not `.vbs.txt` — if you can't see file extensions, go to View → Show → File name extensions in File Explorer)
5. Right-click the file → Edit (or Open with Notepad) and paste this:
```vbs
Set ws = CreateObject("Wscript.Shell")
ws.Run "wsl -d Ubuntu -u root -- service docker start", 0
```
6. Save and close

That's it — next time your PC restarts, WSL starts Docker automatically and all your containers come back up on their own. No commands needed.

## Updating

```bash
cd arrstack
docker compose pull
docker compose up -d
```

## Remote Access with Tailscale (Optional)

Want to access Jellyfin, Seerr, or any service from outside your home? [Tailscale](https://tailscale.com/) creates a private network between your devices — no port forwarding, no exposing anything to the public internet.

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
http://YOUR-TAILSCALE-IP:5055    ← Seerr
http://YOUR-TAILSCALE-IP:7878    ← Radarr
http://YOUR-TAILSCALE-IP:8989    ← Sonarr
```

Find your Tailscale IP with `tailscale ip -4` on the server.

Tailscale is free for personal use (up to 100 devices). Everything is encrypted with WireGuard — nobody can see your traffic, not even Tailscale.

> **Do NOT expose Jellyfin directly to the internet** (no port forwarding on your router). Use Tailscale or a reverse proxy instead. Direct exposure is a security risk.

### Sharing with Family and Friends

Your family and friends only need two things — **Seerr** to request movies/shows and **Jellyfin** to watch them. They never see Radarr, Sonarr, qBittorrent, or any of the behind-the-scenes stuff.

**Step 1: Invite them to your Tailscale network**

1. Go to the [Tailscale admin console](https://login.tailscale.com/admin/machines)
2. Click **Share** on your server's machine
3. Enter their email — they'll get an invite link

**Step 2: They install Tailscale**

1. Download Tailscale on their phone, laptop, or TV from [tailscale.com/download](https://tailscale.com/download)
2. Accept your invite and sign in

**Step 3: They access your services**

Give them these two links (replace with your Tailscale IP):
```
http://YOUR-TAILSCALE-IP:5055    ← Seerr (request movies and shows)
http://YOUR-TAILSCALE-IP:8096    ← Jellyfin (watch everything)
```

**For TVs and phones**, they can install the **Jellyfin app** (available on Roku, Fire TV, Apple TV, Android TV, iOS, Android) and enter your Tailscale IP as the server address during setup.

That's it — they request, you automatically download, they watch. No technical knowledge needed on their end.

## Troubleshooting

**Gluetun unhealthy / won't connect:**
- Double-check VPN credentials in `.env` — these are NOT your login email/password
- Try removing the gluetun folder and restarting: `rm -rf gluetun && docker compose up -d`
- Check logs: `docker logs gluetun`

**qBittorrent can't connect:**
- Make sure Gluetun is healthy: `docker ps` (should show "healthy")
- Check qBit is using VPN: `docker exec gluetun wget -qO- ifconfig.me`
- In qBittorrent settings → Advanced → set Network Interface to `tun0`

**Movie or show not downloading:**
- **Quality profile too strict** — If Radarr/Sonarr can't find a release matching your quality profile, it won't download anything. Go to the movie/show → check if it says "No results found" or similar. Try lowering your cutoff temporarily (e.g. from Bluray-1080p to WEBDL-1080p) or enabling more quality tiers in your profile.
- **Not enough indexers** — Public indexers have limited catalogs. If you only have one or two indexers in Prowlarr, add more (1337x, The Pirate Bay, LimeTorrents, EZTV). The more indexers you have, the more results you'll get.
- **Not enough seeders** — Some torrents just don't have anyone sharing them, especially older or niche content. Check qBittorrent — if the torrent is stuck at 0% with 0 seeds, there's nothing to download. Try searching manually in Radarr/Sonarr for a different release with more seeders.
- **Indexer blocked by Cloudflare** — See the Prowlarr setup note above about setting up FlareSolverr with tags.

**Hard links not working (files copying instead):**
- Both `/data/torrents` and `/data/media` must be on the same filesystem
- Check Radarr/Sonarr → Settings → Media Management → "Use Hardlinks" is checked
- Verify with: `ls -i /data/torrents/movies/yourfile` and `ls -i /data/media/movies/YourMovie/yourfile` — inode numbers should match

**Permission errors:**
- Run `id` and make sure PUID/PGID in `.env` match your user
- Re-run: `sudo chown -R $(id -u):$(id -g) /data`

**Service won't start — "port already in use":**

Another program on your system might be using the same port. This is common with port 5055 (Seerr) but can happen with any service.

1. Find what's using the port (replace `5055` with the port number from the error):

   **Linux:**
   ```bash
   sudo ss -tlnp | grep 5055
   ```

   **Windows (WSL users) — run in PowerShell:**
   ```powershell
   netstat -ano | findstr :5055
   ```
   This gives you a PID (process ID). Find the program name:
   ```powershell
   Get-Process -Id <PID> | Select-Object ProcessName, Id, Path
   ```

2. Either stop/disable that program, or change the port in `docker-compose.yml` to an unused one (e.g. `5056:5055`).

3. If it's a Windows service hogging the port, disable it in an admin PowerShell:
   ```powershell
   Stop-Service <ServiceName> -Force
   Set-Service <ServiceName> -StartupType Disabled
   ```

4. Then recreate the container:
   ```bash
   docker compose up -d --force-recreate <service-name>
   ```

**Can't log into qBittorrent:**
- qBittorrent generates a temporary password every time it starts. Get it with:
  ```bash
  docker logs qbittorrent 2>&1 | grep "temporary password"
  ```
- Default username is `admin`. Once logged in, go to Tools → Options → Web UI and set a permanent password.

**Services can't connect to each other (connection refused, timeout):**
- Don't use `localhost` when connecting services together — that won't work across Docker containers.
- Use the internal Docker IPs instead:
  - qBittorrent/Prowlarr/FlareSolverr: `172.39.0.2`
  - Radarr: `172.39.0.3`
  - Sonarr: `172.39.0.4`
  - Jellyfin: `172.39.0.7`
- The one exception: Prowlarr → FlareSolverr can use `localhost:8191` because they both run through Gluetun and share the same network.

**"Root folder does not exist" in Radarr/Sonarr:**
- Make sure you ran `sudo bash setup-folders.sh` to create the `/data` directory structure.
- Double-check the root folder path — it should be `/data/media/movies` for Radarr and `/data/media/tv` for Sonarr (not `/movies` or `/data/movies`).

**Downloads stuck at "importing" or "waiting to import":**
- This is almost always a permissions issue. Fix it with:
  ```bash
  sudo chown -R $(id -u):$(id -g) /data
  sudo chmod -R 775 /data
  ```
- Make sure PUID/PGID in your `.env` match your user (check with `id`).

**Jellyfin library is empty after downloads finish:**
- Make sure your Jellyfin libraries point to the correct paths: `/data/media/movies`, `/data/media/tv`, `/data/media/music`
- Jellyfin doesn't scan instantly. Go to Dashboard → Libraries → click the `...` menu → **Scan Library** to force a refresh.
- You can also set up scheduled scans in Dashboard → Scheduled Tasks.

**Subtitles not downloading (Bazarr):**
- Bazarr needs to be connected to Radarr and Sonarr: Settings → Radarr / Sonarr → enter the IP (`172.39.0.3` / `172.39.0.4`) and API key.
- You also need at least one subtitle provider: Settings → Providers → Add → **OpenSubtitles.com** is the most popular (free account required).

**Everything works but downloads are slow:**
- Your VPN server might be too far away. Change `SERVER_COUNTRIES` in your `.env` to a country closer to you, then restart:
  ```bash
  docker compose down && docker compose up -d
  ```
- Check your VPN speed: `docker exec gluetun wget -qO- https://speed.cloudflare.com/__down?measId=10000000 > /dev/null` — if it's very slow, try a different country.

**Disk space filling up:**
- By default, qBittorrent keeps torrents after Radarr/Sonarr imports them. To auto-clean:
  - In Radarr/Sonarr → Settings → Download Clients → click on qBittorrent → enable **Remove Completed**
  - This deletes the torrent from qBittorrent after the file has been imported (the hard link in your media folder is kept, so you don't lose anything).

**VPN IP leak — want to make sure your real IP isn't exposed:**
```bash
# Check the VPN container's IP (should NOT be your real IP)
docker exec gluetun wget -qO- ifconfig.me

# Compare with your real IP (run this outside Docker)
curl -s ifconfig.me
```
If both IPs are the same, your VPN isn't working — check Gluetun logs with `docker logs gluetun`.

## Credits

Built by [Tom Spark](https://youtube.com/@tomspark) following [Trash Guides](https://trash-guides.info/) and [Servarr Wiki](https://wiki.servarr.com/) best practices.

Uses [Gluetun](https://github.com/qdm12/gluetun) for VPN, [LinuxServer.io](https://linuxserver.io) container images, and [Seerr](https://github.com/seerr-team/seerr) for the request system (the unified successor to Overseerr/Jellyseerr).
