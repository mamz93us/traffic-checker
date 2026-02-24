# Traffic Checker — Quick Start Guide
## AlmaLinux 8 + WHM/cPanel + Shared Server

---

## What You Need Before Starting

- Root SSH access to your server
- A domain or subdomain ready to use (e.g. `traffic.yourdomain.com`)
- Your cPanel username for that domain
- A cPanel email account (e.g. `alerts@yourdomain.com`) for sending notifications
- Green API account for WhatsApp (free — takes 5 minutes at green-api.com)

---

## Step 1 — Upload the ZIP

In **cPanel → File Manager**, upload `traffic-checker-cpanel.zip` to `/home/yourusername/`
then click **Extract**.

Or via SSH:
```bash
cd /home/yourusername
# upload zip via SFTP first, then:
unzip traffic-checker-cpanel.zip
```

---

## Step 2 — SSH as Root, Run Setup

Open **WHM → Server Configuration → Terminal** or SSH as root:

```bash
cd /home/yourusername/traffic-checker
bash scripts/almalinux_setup.sh
```

**What this installs** (only touches system-level packages, won't affect client sites):
- Chromium browser dependencies (libgbm, libnss3, etc.)
- Python 3 + Playwright library
- Chromium browser itself (~200MB download)
- Xvfb virtual display (runs as `nobody` user — isolated from clients)
- Node.js 20

Takes about **3–5 minutes**.

---

## Step 3 — Deploy to Your Domain

```bash
bash scripts/cpanel_deploy.sh traffic.yourdomain.com yourusername
```

Replace `yourusername` with your actual cPanel username.

**What this does automatically:**
- Creates MySQL database (`yourusername_traff`)
- Creates MySQL user with random password
- Copies all files to `/home/yourusername/traffic-checker/`
- Runs `composer install`
- Runs database migrations
- Creates `.env` file
- Sets file permissions
- Adds cron job to your cPanel account
- **Prints your DB credentials — save them!**

---

## Step 4 — Point Your Domain

In **cPanel → Domains**:

**Option A — Subdomain (recommended, keeps main site untouched):**
1. Create New Domain: `traffic.yourdomain.com`
2. Document Root: `traffic-checker/public`

**Option B — Addon domain or main domain:**
1. Edit domain document root
2. Change to: `traffic-checker/public`

---

## Step 5 — Edit .env Settings

```bash
nano /home/yourusername/traffic-checker/.env
```

**Required changes:**

| Setting | What to put |
|---|---|
| `MAIL_PASSWORD` | Your cPanel email account password |
| `MAIL_USERNAME` | alerts@yourdomain.com |
| `WHATSAPP_INSTANCE_ID` | From green-api.com (see below) |
| `WHATSAPP_ACCESS_TOKEN` | From green-api.com |
| `FILAMENT_ADMIN_PASSWORD` | Choose a strong password |
| `FILAMENT_ADMIN_EMAIL` | Your admin email |

After editing:
```bash
cd /home/yourusername/traffic-checker
/opt/cpanel/ea-php83/root/usr/bin/php artisan config:cache
```

---

## Step 6 — WhatsApp Setup (5 minutes)

1. Go to **https://green-api.com** → Register (free)
2. Click **Create Instance**
3. Scan the QR code with your WhatsApp mobile app
4. Copy your **Instance ID** and **Access Token**
5. Paste into `.env` → run `php artisan config:cache`

Free tier: **2,000 messages/month** — enough for daily vehicle checks.

---

## Step 7 — Login and Add Vehicles

1. Visit `https://traffic.yourdomain.com`
2. Login with your admin email + password from `.env`
3. Go to **Vehicles → Add Vehicle**
4. Fill in: owner name, Arabic plate letters, plate numbers, National ID, phone
5. Enable Email and/or WhatsApp notifications
6. Click **Check Now** to test immediately

---

## Daily Automatic Checks

The cron job was added automatically. It runs the Laravel scheduler every minute,
which triggers the vehicle check at **8:00 AM Cairo time** daily.

To change the schedule, edit `.env`:
```env
CHECK_FREQUENCY=twice_daily   # daily | twice_daily | weekly
CHECK_TIME_1=08:00
CHECK_TIME_2=20:00
```
Then: `php artisan config:cache`

---

## Manual Check via SSH

```bash
cd /home/yourusername/traffic-checker
/opt/cpanel/ea-php83/root/usr/bin/php artisan traffic:check --all --notify
```

---

## Troubleshooting

**"Chromium won't start"**
```bash
# Check Xvfb is running
systemctl status xvfb-traffic
# If not running:
systemctl start xvfb-traffic
# Test Chromium manually:
export DISPLAY=:99
python3 -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True,args=['--no-sandbox']); print('OK'); b.close()"
```

**"Permission denied"**
```bash
chown -R yourusername:yourusername /home/yourusername/traffic-checker
chmod -R 775 /home/yourusername/traffic-checker/storage
```

**"Class not found" PHP errors**
```bash
cd /home/yourusername/traffic-checker
composer dump-autoload
php artisan config:clear
```

**Check error logs**
```bash
tail -50 /home/yourusername/traffic-checker/storage/logs/laravel.log
```

**Test Python wrapper manually**
```bash
export DISPLAY=:99
echo '{"owner":"Test","letter_1":"ل","letter_2":"ط","letter_3":"","numbers":"3112","national_id":"29306191401906","phone":"01226655110","output_dir":"/tmp"}' \
  | python3 /home/yourusername/traffic-checker/scripts/checker_wrapper.py
```

---

## File Locations Summary

| Item | Path |
|---|---|
| Laravel app | `/home/yourusername/traffic-checker/` |
| Public web root | `/home/yourusername/traffic-checker/public/` |
| Python checker | `/home/yourusername/traffic_checker.py` |
| Python wrapper | `/home/yourusername/traffic-checker/scripts/checker_wrapper.py` |
| Config file | `/home/yourusername/traffic-checker/.env` |
| Error logs | `/home/yourusername/traffic-checker/storage/logs/laravel.log` |
| Screenshots | `/home/yourusername/traffic-checker/storage/app/screenshots/` |
