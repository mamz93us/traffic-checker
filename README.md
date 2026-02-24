# 🚗 Egyptian Traffic Violation Checker
## Laravel Dashboard + WhatsApp + Email Alerts

Automated checker for [ppo.gov.eg](https://ppo.gov.eg) with:
- ✅ **Laravel dashboard** — manage vehicles, view history, trigger manual checks
- ✅ **Playwright/Chromium** — full browser automation (handles Oracle APEX tokens)
- ✅ **WhatsApp alerts** — via Green API (free 2000/month) or Twilio
- ✅ **Email alerts** — via SendGrid or any SMTP
- ✅ **Auto-scheduler** — daily/twice-daily checks via Laravel cron
- ✅ **Per-violation details** — date, location, description, fine amount, photo link

---

## Hosting Requirements (Because of Chromium)

| | Works? | Notes |
|---|---|---|
| Shared hosting (cPanel) | ❌ | No shell access, no Chromium |
| VPS 1GB RAM | ⚠️ | Too small — Chromium needs ~500MB |
| **VPS 2-4GB RAM** | **✅ Recommended** | Ubuntu 22.04 LTS |
| Docker container | ✅ | With `--shm-size=1gb` flag |
| AWS Lambda / Serverless | ❌ | No persistent browser |

### Best Value VPS Options:
| Provider | Plan | RAM | Monthly |
|---|---|---|---|
| **Hetzner** (recommended) | CX22 | 4GB | ~€4/mo |
| DigitalOcean | Basic Droplet | 2GB | $12/mo |
| Vultr | Cloud Compute | 2GB | $6/mo |
| Contabo | VPS S | 8GB | €5/mo |

---

## Quick Deploy

```bash
# 1. On your VPS (Ubuntu 22.04), run the setup script:
bash scripts/server_setup.sh

# 2. Upload files to /var/www/traffic-checker/
# 3. Copy traffic_checker.py to /var/www/

# 4. Configure environment:
cp .env.example .env
nano .env   # Fill in DB, mail, WhatsApp settings

# 5. Install + migrate:
composer install --no-dev --optimize-autoloader
php artisan key:generate
php artisan migrate --seed
php artisan storage:link
chown -R www-data:www-data storage bootstrap/cache

# 6. Add cron (auto-checks at 8am daily):
crontab -e
# Add: * * * * * php /var/www/traffic-checker/artisan schedule:run
```

---

## Manual Checks

```bash
# Check all active vehicles + send notifications
php artisan traffic:check --all --notify

# Check one vehicle
php artisan traffic:check --vehicle=1 --notify

# Test without notifications
php artisan traffic:check --all
```

---

## WhatsApp Setup

**Option A: Green API** (Free 2000 msgs/month — recommended)
1. Register at https://green-api.com
2. Create instance → scan QR with your phone
3. Add to .env: `WHATSAPP_INSTANCE_ID=...` and `WHATSAPP_ACCESS_TOKEN=...`

**Option B: Twilio**
1. Register at https://twilio.com → enable WhatsApp Sandbox
2. Add to .env: `WHATSAPP_PROVIDER=twilio` + Twilio credentials

---

## File Structure

```
traffic-checker/
├── traffic_checker.py              ← Python/Playwright automation script
├── scripts/
│   ├── checker_wrapper.py          ← Laravel↔Python bridge (stdin/stdout JSON)
│   └── server_setup.sh             ← One-command Ubuntu server setup
├── app/
│   ├── Services/
│   │   ├── PlaywrightCheckerService.php  ← Runs Python subprocess
│   │   ├── WhatsAppService.php           ← Green API + Twilio
│   │   └── NotificationService.php       ← Orchestrates email + WhatsApp
│   ├── Models/Vehicle.php
│   ├── Models/ViolationCheck.php
│   ├── Http/Controllers/
│   │   ├── DashboardController.php
│   │   ├── VehicleController.php
│   │   └── ViolationController.php
│   └── Console/Commands/CheckTrafficViolations.php
├── resources/views/
│   ├── layouts/app.blade.php       ← Sidebar layout (Tailwind CSS)
│   ├── dashboard/index.blade.php   ← Main dashboard
│   ├── vehicles/                   ← CRUD views
│   ├── violations/                 ← Violation detail views
│   └── emails/violation-alert.blade.php
└── database/migrations/
```

---

## Default Login

After `php artisan migrate --seed`:
- Email: value of `FILAMENT_ADMIN_EMAIL` in .env
- Password: value of `FILAMENT_ADMIN_PASSWORD` in .env

