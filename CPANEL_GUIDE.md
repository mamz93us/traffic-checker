# Traffic Checker — Complete WHM/cPanel Deployment Guide

## ════════════════════════════════════════════════════════
## STEP 1 — SSH Terminal Setup (run as root)
## ════════════════════════════════════════════════════════

Connect via terminal (SSH or WHM Terminal):

```bash
# Upload the zip first (via cPanel File Manager or SCP), then:
cd /root
unzip traffic-checker-cpanel.zip
cd traffic-checker-cpanel

# Run the system setup (installs Chromium, Node, Xvfb, Playwright)
bash cpanel_setup.sh
```

This takes about 3–5 minutes. You'll see:
- ✓ System libraries installed
- ✓ Node vXX.X ready
- ✓ Playwright + Chromium installed
- ✓ Xvfb running on :99

---

## ════════════════════════════════════════════════════════
## STEP 2 — Deploy to Your Domain
## ════════════════════════════════════════════════════════

```bash
# Replace with your actual domain and cPanel username
bash cpanel_deploy.sh yourdomain.com your_cpanel_username
```

This automatically:
- Creates MySQL database + user
- Copies files to `/home/USERNAME/traffic-checker/`
- Runs `composer install`
- Runs `php artisan migrate --seed`
- Creates your `.env` file
- Shows you exactly what to do next

**Save the database password it prints — you'll need it!**

---

## ════════════════════════════════════════════════════════
## STEP 3 — Point Your Domain
## ════════════════════════════════════════════════════════

**Option A: Use a subdomain (recommended)**

In cPanel → Domains → Create New Domain:
- Domain: `traffic.yourdomain.com`
- Document Root: `traffic-checker/public`

**Option B: Use main domain or addon domain**

In cPanel → Domains → click your domain → Edit Document Root:
- Change to: `traffic-checker/public`

**Option C: Subfolder via .htaccess (if you can't change doc root)**

Add to your `public_html/.htaccess`:
```apache
RewriteEngine On
RewriteRule ^traffic(/.*)?$ /home/USERNAME/traffic-checker/public$1 [L]
```

---

## ════════════════════════════════════════════════════════
## STEP 4 — Add Cron Job in cPanel
## ════════════════════════════════════════════════════════

cPanel → Cron Jobs → Add New Cron Job:

**For automatic daily checks (recommended):**
```
Minute: 0
Hour: 8
Day: *
Month: *
Weekday: *
Command: /opt/cpanel/ea-php83/root/usr/bin/php /home/USERNAME/traffic-checker/artisan traffic:check --all --notify >> /dev/null 2>&1
```

**For Laravel scheduler (runs every minute, checks on schedule):**
```
Minute: *
Hour: *
Day: *
Month: *
Weekday: *
Command: /opt/cpanel/ea-php83/root/usr/bin/php /home/USERNAME/traffic-checker/artisan schedule:run >> /dev/null 2>&1
```

> **Note:** Replace `ea-php83` with your PHP version. Find it by running:
> `ls /opt/cpanel/ | grep ea-php`

---

## ════════════════════════════════════════════════════════
## STEP 5 — Edit .env File
## ════════════════════════════════════════════════════════

File location: `/home/USERNAME/traffic-checker/.env`

Edit via cPanel File Manager or terminal:
```bash
nano /home/USERNAME/traffic-checker/.env
```

**Required settings to fill in:**

```env
# ── Email (use your cPanel email) ────────────────────────
MAIL_HOST=mail.yourdomain.com
MAIL_PORT=587
MAIL_USERNAME=alerts@yourdomain.com
MAIL_PASSWORD=your_email_password       # ← cPanel email password
MAIL_FROM_ADDRESS=alerts@yourdomain.com

# ── WhatsApp (Green API — free 2000 msgs/month) ──────────
# Sign up at https://green-api.com → create instance → scan QR
WHATSAPP_INSTANCE_ID=1234567890
WHATSAPP_ACCESS_TOKEN=your_token_here

# ── Admin login ──────────────────────────────────────────
FILAMENT_ADMIN_EMAIL=admin@yourdomain.com
FILAMENT_ADMIN_PASSWORD=choose_strong_password

# ── Schedule ─────────────────────────────────────────────
CHECK_FREQUENCY=daily     # daily | twice_daily | weekly
CHECK_TIME_1=08:00        # Morning check
CHECK_TIME_2=20:00        # Evening check (if twice_daily)
```

After editing, clear cache:
```bash
cd /home/USERNAME/traffic-checker
php artisan config:clear && php artisan config:cache
```

---

## ════════════════════════════════════════════════════════
## STEP 6 — Login and Add Vehicles
## ════════════════════════════════════════════════════════

1. Visit `https://traffic.yourdomain.com`
2. Login with the email/password from your `.env`
3. Click **Vehicles → Add Vehicle**
4. Fill in: Owner name, Arabic plate letters, plate number, National ID, phone
5. Check the notification options (Email / WhatsApp)
6. Click **Check Now** to test immediately

---

## ════════════════════════════════════════════════════════
## IMPORTANT: cPanel-Specific PHP Path
## ════════════════════════════════════════════════════════

cPanel uses its own PHP binaries, NOT `/usr/bin/php`.

Find your PHP path:
```bash
ls /opt/cpanel/ | grep ea-php
```

Common paths:
```
/opt/cpanel/ea-php83/root/usr/bin/php   ← PHP 8.3
/opt/cpanel/ea-php82/root/usr/bin/php   ← PHP 8.2
/opt/cpanel/ea-php81/root/usr/bin/php   ← PHP 8.1
```

Use this exact path in cron jobs and when running artisan commands.

---

## ════════════════════════════════════════════════════════
## TROUBLESHOOTING
## ════════════════════════════════════════════════════════

**Chromium won't start?**
```bash
# Check Xvfb is running
ps aux | grep Xvfb
# Start it manually if not running
Xvfb :99 -screen 0 1280x1024x24 -ac &
# Set display variable
export DISPLAY=:99
```

**Permission errors?**
```bash
chown -R USERNAME:USERNAME /home/USERNAME/traffic-checker
chmod -R 755 /home/USERNAME/traffic-checker
chmod -R 775 /home/USERNAME/traffic-checker/storage
```

**Test the Python script manually:**
```bash
export DISPLAY=:99
echo '{"owner":"Test","letter_1":"ل","letter_2":"ط","letter_3":"","numbers":"3112","national_id":"29306191401906","phone":"01226655110","output_dir":"/tmp"}' \
  | python3 /home/USERNAME/traffic-checker/scripts/checker_wrapper.py
```

**Test artisan commands:**
```bash
cd /home/USERNAME/traffic-checker
/opt/cpanel/ea-php83/root/usr/bin/php artisan traffic:check --all
```

**Check Laravel logs:**
```bash
tail -f /home/USERNAME/traffic-checker/storage/logs/laravel.log
```

**CloudLinux/CageFS issues?**
If Chromium can't find libraries due to CloudLinux CageFS:
```bash
# In WHM → CloudLinux → CageFS → Add to /etc/cagefs/conf.d/ a new file:
# chromium.cfg with:
[chromium]
comment=Chromium libs
paths=/root/.cache/ms-playwright
```
Or disable CageFS for your user in WHM → CloudLinux → CageFS → Users.

