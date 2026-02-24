#!/usr/bin/env python3
"""
Laravel → Python bridge for traffic_checker.py

Reads ONE vehicle as JSON from stdin.
Writes ONE result as JSON to stdout.

Called by PlaywrightCheckerService::runPythonScript()

Usage (Laravel calls this automatically):
    echo '{"owner":"...","letter_1":"ل",...}' | python3 checker_wrapper.py
"""

import sys
import json
import os
import glob
import shutil

# ── Load the main checker (same directory or parent) ──────────
script_dir = os.path.dirname(os.path.abspath(__file__))
for candidate in [
    os.path.join(script_dir, '..', 'traffic_checker.py'),
    os.path.join(script_dir, 'traffic_checker.py'),
    '/var/www/traffic_checker.py',
]:
    candidate = os.path.normpath(candidate)
    if os.path.exists(candidate):
        # Execute the main script to import its functions
        with open(candidate) as f:
            src = f.read()
        # Override HEADLESS before exec so the script starts headless
        src = src.replace('HEADLESS = False', 'HEADLESS = True')
        src = src.replace('SAVE_VIOLATION_PHOTOS   = True', 'SAVE_VIOLATION_PHOTOS   = False')
        exec(compile(src, candidate, 'exec'), globals())
        break
else:
    print(json.dumps({"error": "traffic_checker.py not found"}))
    sys.exit(2)

# ── Read vehicle data from stdin ───────────────────────────────
try:
    vehicle = json.loads(sys.stdin.read())
except json.JSONDecodeError as e:
    print(json.dumps({"error": f"Invalid JSON input: {e}"}))
    sys.exit(2)

output_dir = vehicle.get('output_dir', '/tmp/traffic_screenshots')
os.makedirs(output_dir, exist_ok=True)

# ── Run the Playwright check ───────────────────────────────────
result = {}

try:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            headless=True,
            slow_mo=300,
            args=[
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--disable-blink-features=AutomationControlled',
                '--disable-gpu',
            ],
        )
        ctx = browser.new_context(
            locale='ar-EG',
            timezone_id='Africa/Cairo',
            viewport={'width': 1280, 'height': 900},
            user_agent=(
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/122.0.0.0 Safari/537.36'
            ),
            extra_http_headers={'Accept-Language': 'ar-EG,ar;q=0.9,en;q=0.8'},
        )
        page = ctx.new_page()
        page.set_default_timeout(40_000)
        result = check_vehicle(page, vehicle)
        browser.close()

except Exception as e:
    result['error'] = str(e)
    result['status'] = 'error'

# ── Move screenshot to output_dir ─────────────────────────────
plate = vehicle.get('numbers', 'unknown')
for pattern in [f"result_{plate}*.png", f"result_*.png"]:
    for f in glob.glob(pattern):
        dest = os.path.join(output_dir, os.path.basename(f))
        shutil.move(f, dest)
        result['screenshot_path'] = dest
        break

# ── Output JSON to stdout (Laravel reads this) ────────────────
print(json.dumps(result, ensure_ascii=False))
