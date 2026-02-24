#!/usr/bin/env python3
"""
Laravel → Python bridge for traffic_checker.py
Works on both VPS and WHM/cPanel servers.

Reads ONE vehicle as JSON from stdin.
Writes ONE result as JSON to stdout.
All other output (print statements from traffic_checker.py) goes to stderr.
"""

import sys, json, os, glob, shutil

# ── Find and load traffic_checker.py ──────────────────────────
script_dir = os.path.dirname(os.path.abspath(__file__))
search_paths = [
    os.path.join(script_dir, '..', 'traffic_checker.py'),
    os.path.join(script_dir, 'traffic_checker.py'),
    os.path.join(os.path.expanduser('~'), 'traffic_checker.py'),
    '/var/www/traffic_checker.py',
    '/home/' + os.environ.get('LOGNAME', '') + '/traffic_checker.py',
]

loaded = False
for path in search_paths:
    path = os.path.normpath(path)
    if os.path.exists(path):
        with open(path) as f:
            src = f.read()

        # Force server-safe settings
        src = src.replace('HEADLESS = False',               'HEADLESS = True')
        src = src.replace('SAVE_VIOLATION_PHOTOS   = True', 'SAVE_VIOLATION_PHOTOS   = False')
        src = src.replace('OUTPUT_JSON             = "violations_report.json"',
                          'OUTPUT_JSON             = None')

        # Execute in a namespace where __name__ != '__main__' so that
        # the script's  `if __name__ == "__main__": sys.exit(main())`
        # block does NOT run — we only want the function definitions.
        try:
            module_globals = {'__name__': 'traffic_checker_module', '__file__': path}
            exec(compile(src, path, 'exec'), module_globals)
            # Pull the defined functions/globals into our own namespace
            globals().update({k: v for k, v in module_globals.items()
                              if not k.startswith('__')})
        except Exception as e:
            print(json.dumps({"error": f"Failed to load traffic_checker.py: {e}"}))
            sys.exit(2)

        loaded = True
        break

if not loaded:
    print(json.dumps({"error": "traffic_checker.py not found. Searched: " + str(search_paths)}))
    sys.exit(2)

# ── Read vehicle JSON from stdin ──────────────────────────────
try:
    vehicle = json.loads(sys.stdin.read())
except json.JSONDecodeError as e:
    print(json.dumps({"error": f"Invalid JSON from stdin: {e}"}))
    sys.exit(2)

output_dir = vehicle.get('output_dir', '/tmp/traffic_screenshots')
os.makedirs(output_dir, exist_ok=True)

# ── Redirect stdout → stderr during the check ─────────────────
# traffic_checker.py has many print() statements (progress output,
# box-drawing separators, etc.).  By redirecting stdout to stderr
# while the check runs, we keep stdout clean for our final JSON.
_real_stdout = sys.stdout
sys.stdout = sys.stderr

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
                '--single-process',   # Helps on cPanel/CloudLinux
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
finally:
    # Always restore real stdout before printing the result
    sys.stdout = _real_stdout

# ── Move screenshots to output_dir ────────────────────────────
plate = vehicle.get('numbers', 'unknown')
for pattern in [f"result_{plate}*.png", "result_*.png"]:
    for f in glob.glob(pattern):
        dest = os.path.join(output_dir, os.path.basename(f))
        shutil.move(f, dest)
        result['screenshot_path'] = dest
        break

# ── Output clean JSON to stdout ───────────────────────────────
print(json.dumps(result, ensure_ascii=False))
