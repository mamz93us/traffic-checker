#!/bin/bash
# Fix Xvfb on AlmaLinux 9 + WHM/cPanel
# Run as root

echo "Fixing Xvfb virtual display..."

# Stop the broken service
systemctl stop xvfb-traffic 2>/dev/null || true
systemctl disable xvfb-traffic 2>/dev/null || true

# Kill any stuck Xvfb processes
pkill -f "Xvfb :99" 2>/dev/null || true
rm -f /tmp/.X99-lock 2>/dev/null || true
sleep 1

# Recreate service — run as ROOT (nobody can't own X displays on RHEL9)
cat > /etc/systemd/system/xvfb-traffic.service << 'SERVICE'
[Unit]
Description=Xvfb Virtual Display for Traffic Checker
After=network.target

[Service]
Type=simple
ExecStartPre=/bin/rm -f /tmp/.X99-lock
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX -nolisten tcp
Restart=on-failure
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable xvfb-traffic
systemctl start xvfb-traffic
sleep 2

# Verify
if systemctl is-active --quiet xvfb-traffic; then
    echo "  ✓ Xvfb is running on display :99"
else
    echo "  ✗ Service still failing — trying direct launch..."
    rm -f /tmp/.X99-lock
    nohup /usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX -nolisten tcp > /var/log/xvfb.log 2>&1 &
    sleep 2
    if pgrep -f "Xvfb :99" > /dev/null; then
        echo "  ✓ Xvfb running directly (PID: $(pgrep -f 'Xvfb :99'))"
        # Add to crontab so it restarts on reboot
        (crontab -l 2>/dev/null | grep -v "Xvfb"; echo "@reboot rm -f /tmp/.X99-lock && nohup /usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac > /var/log/xvfb.log 2>&1 &") | crontab -
        echo "  ✓ Added @reboot cron as backup"
    else
        echo "  ✗ Xvfb failed to start — check: journalctl -u xvfb-traffic"
        exit 1
    fi
fi

# Test Chromium with DISPLAY set
echo ""
echo "  Testing Chromium with DISPLAY=:99..."
export DISPLAY=:99
python3 -c "
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(
        headless=True,
        args=['--no-sandbox','--disable-dev-shm-usage','--disable-gpu']
    )
    page = b.new_page()
    page.goto('about:blank')
    b.close()
print('  ✓ Chromium + DISPLAY=:99 working perfectly')
" && echo "" && echo "  ✅ All done! Xvfb and Chromium are ready." \
|| echo "  ⚠  Chromium test failed — run: export DISPLAY=:99 && python3 -c 'from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=True,args=[\"--no-sandbox\"]); print(\"OK\"); b.close()'"

echo ""
echo "  Xvfb status: $(systemctl is-active xvfb-traffic 2>/dev/null || echo 'direct process')"
echo "  Display:     :99"
echo ""
echo "  NEXT STEP: run the deploy script:"
echo "    bash cpanel_deploy.sh yourdomain.com your_cpanel_username"
