#!/usr/bin/env python3
"""
Egyptian Traffic Violation Checker
ppo.gov.eg  —  Egyptian Public Prosecution Office

FLOW (confirmed by full HTML reverse-engineering):
  Page 14  →  Enter plate (Arabic letters + number)
               Button: id="GET_FIN_LETTER_NUMBERS_BTN"
  Page  7  →  Enter National ID + mobile phone
               Button: class="sameSubmitBtn" (first one on page)
  Page 16  →  Results: fee summary + individual violation table
               Photo popup URL:
               /ppo/r/ppoportal/ppoportal/violation-form-image?p2_fineid={ID}&session={S}
               Where ID = data-id attribute value with "ck-" prefix stripped

INSTALL:
    pip install playwright
    python -m playwright install chromium

RUN:
    python traffic_checker.py

OUTPUT FILES:
    violations_report.json        — full structured report
    result_PLATE_HHMMSS.png       — screenshot of results page
    photo_PLATE_FINEID.png        — screenshot of each violation photo (if enabled)
"""

import re
import sys
import time
import json
from datetime import datetime
from playwright.sync_api import sync_playwright, Page, TimeoutError as PWTimeout


# ╔══════════════════════════════════════════════════════════════════╗
# ║                    ⚙  CONFIGURATION                              ║
# ╚══════════════════════════════════════════════════════════════════╝

VEHICLES = [
    {
        # Label used in the report (your reference only)
        "owner": "Car Owner Name",

        # Arabic plate letters — up to 3 characters, one per field
        # Leave letter_3 empty if the plate has only 2 letters
        "letter_1": "ل",
        "letter_2": "ط",
        "letter_3": "",

        # Plate number (up to 4 digits)
        "numbers": "3112",

        # 14-digit Egyptian National ID
        "national_id": "29306191401906",

        # Mobile number (11 digits, starts with 010/011/012/015)
        "phone": "01226655110",
    },
    # ── Add more vehicles below ─────────────────────────────────────
    # {
    #     "owner":      "Second Car",
    #     "letter_1":   "أ",
    #     "letter_2":   "ب",
    #     "letter_3":   "ج",
    #     "numbers":    "5678",
    #     "national_id": "12345678901234",
    #     "phone":      "01000000000",
    # },
]

# ── Browser settings ────────────────────────────────────────────────
HEADLESS = False    # False = show browser window (recommended first time)
                    # True  = no window, silent mode (good for cron/server)
SLOW_MO  = 600      # Milliseconds between actions. Increase to 1000+ if site is slow.
TIMEOUT  = 40_000   # Milliseconds per wait/click (40 seconds)

# ── Output settings ─────────────────────────────────────────────────
SAVE_RESULT_SCREENSHOT  = True   # Screenshot the full results page
SAVE_VIOLATION_PHOTOS   = True   # Screenshot each individual violation photo popup
OUTPUT_JSON             = "violations_report.json"

# ╚══════════════════════════════════════════════════════════════════╝


BASE_URL = "https://ppo.gov.eg/ppo/r/ppoportal/ppoportal/traffic"


# ────────────────────────────────────────────────────────────────────
#  MAIN CHECK FLOW
# ────────────────────────────────────────────────────────────────────

def check_vehicle(page: Page, v: dict) -> dict:
    """Run the complete check for one vehicle. Returns a result dict."""
    plate = f"{v['letter_1']}{v['letter_2']}{v.get('letter_3', '')}{v['numbers']}"

    result = {
        "owner":          v["owner"],
        "plate":          plate,
        "checked_at":     datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "has_violations": False,
        "violations":     [],       # list of individual violation dicts
        "fines":          "0",      # اجمالي الغرامات الشاملة
        "court_fees":     "0",      # الرسوم القضائية
        "service_fees":   "0",      # خدمة مميكنة / مصاريف خدمة النيابة
        "appeal_fees":    "0",      # رسوم التظلم الإلكتروني
        "postal_fees":    "0",      # مصاريف خدمة البريد
        "grand_total":    "0",      # اجمالي الغرامات الشاملة والرسوم القضائية
        "owner_name":     "",       # License holder name (from results page)
        "license_number": "",       # License number (from results page)
        "message":        "",
        "error":          "",
    }

    try:
        _step1_enter_plate(page, v, plate)
        _step2_enter_identity(page, v)
        result = _step3_parse_results(page, result)
    except PWTimeout as e:
        result["error"]   = f"Timeout: {e}"
        result["message"] = "ERROR: Connection timed out"
        _save_screenshot(page, f"error_{plate}.png")
    except Exception as e:
        result["error"]   = str(e)
        result["message"] = f"ERROR: {e}"
        _save_screenshot(page, f"error_{plate}.png")

    return result


def _step1_enter_plate(page: Page, v: dict, plate: str):
    """
    Page 14: Open the traffic page and fill in the plate details.

    Key elements (confirmed from نيابات_المرور.html):
        Radio "letters+numbers" : id="P14_CHOSE_OPTION_0"  value="1"
        Letter fields           : #P14_LETER_1, #P14_LETER_2, #P14_LETER_3 (maxlength=1)
        Number field            : #P14_NUMBER_WITH_LETTER
        Search button           : id="GET_FIN_LETTER_NUMBERS_BTN"
    """
    print(f"\n  {'═' * 60}")
    print(f"  Vehicle : {v['owner']}  |  Plate : {plate}")
    print(f"  {'═' * 60}")
    print("  [1/3] Opening traffic page...")

    page.goto(BASE_URL, wait_until="networkidle", timeout=TIMEOUT)
    page.wait_for_selector("#P14_LETER_1", state="visible", timeout=TIMEOUT)
    print("        ✓ Page loaded")

    # Select "حروف وأرقام" (letters + numbers) — should already be checked
    if not page.locator("#P14_CHOSE_OPTION_0").is_checked():
        page.click("#P14_CHOSE_OPTION_0")
        time.sleep(0.4)

    # Fill plate letters (each field accepts 1 character)
    page.fill("#P14_LETER_1", v["letter_1"])
    time.sleep(0.2)
    page.fill("#P14_LETER_2", v["letter_2"])
    time.sleep(0.2)
    if v.get("letter_3"):
        page.fill("#P14_LETER_3", v["letter_3"])
        time.sleep(0.2)
    page.fill("#P14_NUMBER_WITH_LETTER", v["numbers"])
    time.sleep(0.3)
    print(f"        ✓ Plate entered: {plate}")

    page.click("#GET_FIN_LETTER_NUMBERS_BTN", timeout=TIMEOUT)
    print("        ✓ Search submitted")


def _step2_enter_identity(page: Page, v: dict):
    """
    Page 7: Enter National ID and phone number.

    Key elements (confirmed from إدارة_المرور_-_تحقيق_الشخصيه.html):
        National ID field : id="P7_NATIONAL_ID_CASE_1"    (maxlength=14)
        Phone field       : id="P7_PHONE_NUMBER_ID_CASE_1" (maxlength=11)
        Submit button     : class="sameSubmitBtn"  (only one on this page)
    """
    print("  [2/3] Identity verification...")
    page.wait_for_selector("#P7_NATIONAL_ID_CASE_1", state="visible", timeout=TIMEOUT)
    print("        ✓ Identity page loaded")

    page.fill("#P7_NATIONAL_ID_CASE_1",     v["national_id"])
    time.sleep(0.3)
    page.fill("#P7_PHONE_NUMBER_ID_CASE_1", v["phone"])
    time.sleep(0.4)
    print("        ✓ National ID and phone entered")

    page.locator("button.sameSubmitBtn").first.click(timeout=TIMEOUT)
    print("        ✓ Form submitted")


def _step3_parse_results(page: Page, result: dict) -> dict:
    """
    Page 16: Wait for results then extract all data.

    Structure confirmed from two real HTML saves:
        تفاصيل_المخالفات.html            — page WITH violations (65 violations, 23,800 EGP)
        لا_توجد_مخالفات_مرورية.html       — page WITHOUT violations

    No-violations indicator:
        Text: "اجمالي الغرامات الشاملة والرسوم القضائية لا يوجد"

    Fee summary labels:
        WITH violations  : "اجمالي الغرامات الشاملة"  "الرسوم القضائية"  "خدمة مميكنة"
                           "رسوم التظلم الإلكتروني"
                           "اجمالي الغرامات الشاملة والرسوم القضائية"  (grand total)
        WITHOUT          : same labels + "مصاريف خدمة النيابة"  "مصاريف خدمة البريد"
                           "الاجمالى"  (grand total)

    Violation table columns:
        F_DATE        — date (dd/mm/yyyy)
        F_PLACE       — location; contains <p class="fine-image" data-id="ck-FINEID">
        N_FINEDESC    — violation description (Arabic)
        N_F_MINVALUE  — minimum fine
        N_F_MAXVALUE  — maximum fine
        N_F_VALUE     — actual fine charged

    Violation photo system:
        Each photo button: <p class="fine-image" data-id="ck-101352501151776">
        Clicking it opens APEX dialog with iframe loading:
          /ppo/r/ppoportal/ppoportal/violation-form-image?p2_fineid=101352501151776&session=SESSION
        The fine_id = data-id with "ck-" prefix removed
    """
    print("  [3/3] Waiting for results...")
    page.wait_for_load_state("networkidle", timeout=TIMEOUT)
    time.sleep(2.5)
    print("        ✓ Results page loaded")

    plate = result["plate"]

    if SAVE_RESULT_SCREENSHOT:
        fname = f"result_{plate}_{datetime.now().strftime('%H%M%S')}.png"
        page.screenshot(path=fname, full_page=True)
        print(f"        📸 Results screenshot: {fname}")

    html = page.content()
    text = page.inner_text("body")

    _extract_owner_info(text, result)
    _extract_fee_summary(text, result)

    # No-violations check
    no_vio = (
        "اجمالي الغرامات الشاملة والرسوم القضائية لا يوجد" in text
        or "لا توجد مخالفات" in text
    )
    fines_int = int(result["fines"]) if result["fines"].isdigit() else 0

    if no_vio and fines_int == 0:
        result["has_violations"] = False
        result["message"]        = "No violations found"
        print("        ✅ Result: NO violations")
        return result

    # Parse individual violation rows
    violations = _parse_violation_table(html)
    result["violations"] = violations

    if fines_int > 0 or violations:
        result["has_violations"] = True
        result["message"] = (
            f"{len(violations)} violation(s) — "
            f"Grand Total: {result['grand_total']} EGP"
        )
        print(f"        ⚠️  Result: {len(violations)} violations | "
              f"Grand Total: {result['grand_total']} EGP")

        if SAVE_VIOLATION_PHOTOS and violations:
            _capture_all_photos(page, violations, plate)
    else:
        result["has_violations"] = False
        result["message"]        = "No violations found"
        print("        ✅ Result: NO violations")

    return result


# ────────────────────────────────────────────────────────────────────
#  VIOLATION PHOTO CAPTURE
# ────────────────────────────────────────────────────────────────────

def _capture_all_photos(page: Page, violations: list, plate: str):
    """
    Screenshot every violation photo popup.

    How the photo system works (confirmed from تفاصيل_المخالفات_htmlwith_image.html):
      1. Each violation row has:  <p class="fine-image" data-id="ck-101352501151776">
      2. Clicking it triggers APEX dynamic action:
           a) Sets P16_FINE_ID = "101352501151776"  (strips "ck-" prefix)
           b) Calls PL/SQL via AJAX → writes result URL into P16_URL hidden field
           c) P16_URL value = javascript:apex.theme42.dialog('/ppo/.../violation-form-image
                               ?p2_fineid=101352501151776&session=SESSION', ...)
           d) APEX opens a modal dialog containing an iframe with the photo page
      3. We click the element, wait for the dialog iframe, then screenshot it
    """
    photo_buttons = page.locator("p.fine-image").all()
    total = len(photo_buttons)
    print(f"\n        📷 Capturing {total} violation photos...")

    for idx, btn in enumerate(photo_buttons, 1):
        raw_id = btn.get_attribute("data-id") or ""
        fine_id = raw_id.replace("ck-", "").strip()
        if not fine_id:
            continue

        try:
            btn.scroll_into_view_if_needed()
            time.sleep(0.3)
            btn.click(timeout=10_000)

            # Wait for the APEX dialog modal to open
            page.wait_for_selector(
                "#apex_dialog_1, .ui-dialog[style*='display: block'], "
                ".t-Dialog-body, [role='dialog']",
                state="visible",
                timeout=10_000
            )
            time.sleep(1.5)   # Let iframe content load

            fname = f"photo_{plate}_{fine_id}.png"
            page.screenshot(path=fname)
            print(f"           [{idx:02d}/{total}] ✓ {fname}")

            # Store filename in the matching violation record
            for v in violations:
                if v.get("fine_id") == fine_id:
                    v["photo_file"] = fname
                    break

            # Close the dialog
            closed = False
            for close_sel in [
                "button.ui-dialog-titlebar-close",
                ".ui-dialog-titlebar-close",
                "button[aria-label='Close']",
                "button[title='Close']",
            ]:
                try:
                    cb = page.locator(close_sel).first
                    if cb.is_visible():
                        cb.click()
                        closed = True
                        break
                except Exception:
                    pass
            if not closed:
                page.keyboard.press("Escape")

            time.sleep(0.6)

        except PWTimeout:
            print(f"           [{idx:02d}/{total}] ⚠ Timeout — photo dialog did not open "
                  f"(fine_id={fine_id})")
        except Exception as e:
            print(f"           [{idx:02d}/{total}] ⚠ Error: {e}")


# ────────────────────────────────────────────────────────────────────
#  PARSERS
# ────────────────────────────────────────────────────────────────────

def _parse_violation_table(html: str) -> list:
    """
    Extract every violation row from the Page 16 results table.

    Table header row (confirmed):
        تظلم | تاريخ الواقعة | مكان الواقعة | التوصيف الجنائى | الحد الأدنى | الحد الأقصى | الغرامه الشاملة

    HTML column mapping:
        headers="F_DATE"       → violation date
        headers="F_PLACE"      → location text + fine-image button
        headers="N_FINEDESC"   → violation description
        headers="N_F_MINVALUE" → minimum possible fine (EGP)
        headers="N_F_MAXVALUE" → maximum possible fine (EGP)
        headers="N_F_VALUE"    → actual fine charged (EGP)

    Photo ID extraction:
        Inside F_PLACE cell: <p class="fine-image" data-id="ck-101352501151776">
        fine_id = data-id value with "ck-" stripped = "101352501151776"
        Photo URL = https://ppo.gov.eg/ppo/r/ppoportal/ppoportal/
                    violation-form-image?p2_fineid=101352501151776&session=SESSION
    """
    violations = []
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.DOTALL)

    for row in rows:
        # Only process data rows (contain F_DATE column)
        if 'headers="F_DATE"' not in row:
            continue

        def cell(col):
            m = re.search(rf'headers="{col}"[^>]*>(.*?)</td>', row, re.DOTALL)
            return m.group(1) if m else ""

        def clean(raw):
            t = re.sub(r'<[^>]+>', ' ', raw)
            return re.sub(r'\s+', ' ', t).strip()

        place_raw = cell("F_PLACE")
        date      = clean(cell("F_DATE"))
        desc      = clean(cell("N_FINEDESC"))

        if not date and not desc:
            continue   # skip empty/separator rows

        # Extract fine_id from  data-id="ck-XXXXXXXXXXXXXXX"
        photo_m  = re.search(r'data-id="ck-(\d+)"', place_raw)
        fine_id  = photo_m.group(1) if photo_m else ""

        # Remove the Arabic "photo" button text from location string
        place = clean(place_raw).replace("صورة نموذج المخالفة", "").strip()

        violations.append({
            "date":        date,
            "location":    place,
            "description": desc,
            "min_fine":    clean(cell("N_F_MINVALUE")),
            "max_fine":    clean(cell("N_F_MAXVALUE")),
            "fine_amount": clean(cell("N_F_VALUE")),
            "fine_id":     fine_id,
            "photo_url":   (
                f"https://ppo.gov.eg/ppo/r/ppoportal/ppoportal/"
                f"violation-form-image?p2_fineid={fine_id}"
                if fine_id else ""
            ),
            "photo_file":  "",   # filled in after screenshot
        })

    return violations


def _extract_fee_summary(text: str, result: dict):
    """
    Extract all fee totals from the plain text of Page 16.

    Labels present on violations page (تفاصيل_المخالفات.html, 65 violations):
        اجمالي الغرامات الشاملة                          23800
        الرسوم القضائية                                   325
        خدمة مميكنة                                       100
        رسوم التظلم الإلكتروني                            100
        اجمالي الغرامات الشاملة والرسوم القضائية          24325  ← grand total

    Labels present on no-violations page (لا_توجد_مخالفات_مرورية.html):
        اجمالي الغرامات الشاملة                          0
        الرسوم القضائية                                  0
        مصاريف خدمة النيابة                              100
        رسوم التظلم الإلكتروني                           0
        مصاريف خدمة البريد                               15
        الاجمالى                                         115    ← grand total
    """
    def get(label):
        m = re.search(rf"{re.escape(label)}\s*([\d,]+)", text)
        return m.group(1).replace(",", "") if m else "0"

    result["fines"]       = get("اجمالي الغرامات الشاملة")
    result["court_fees"]  = get("الرسوم القضائية")
    # service fee label differs between the two pages
    result["service_fees"] = get("خدمة مميكنة") or get("مصاريف خدمة النيابة")
    result["appeal_fees"] = get("رسوم التظلم الإلكتروني")
    result["postal_fees"] = get("مصاريف خدمة البريد")
    # grand total label also differs
    result["grand_total"] = (
        get("اجمالي الغرامات الشاملة والرسوم القضائية") or
        get("الاجمالى")
    )


def _extract_owner_info(text: str, result: dict):
    """Extract license owner name and license number from results page."""
    m = re.search(r"اسم المالك\s+(.+?)(?:\n|رقم الرخصة)", text)
    if m:
        result["owner_name"] = m.group(1).strip()

    m = re.search(r"رقم الرخصة\s+(\S+)", text)
    if m:
        result["license_number"] = m.group(1).strip()


# ────────────────────────────────────────────────────────────────────
#  REPORT
# ────────────────────────────────────────────────────────────────────

def print_report(results: list):
    """Print a formatted console report and save violations_report.json."""
    print("\n\n")
    W = 68
    print("╔" + "═" * W + "╗")
    print("║" + "  Egyptian Traffic Violations Report  —  ppo.gov.eg".center(W) + "║")
    print("║" + datetime.now().strftime("%Y-%m-%d %H:%M:%S").center(W) + "║")
    print("╚" + "═" * W + "╝")

    for r in results:
        ok   = not r["has_violations"]
        icon = "✅" if ok else "⚠️ "
        print(f"\n  {icon} {r['owner']}")
        print(f"     Plate          : {r['plate']}")
        if r.get("owner_name"):
            print(f"     License Owner  : {r['owner_name']}")
        if r.get("license_number"):
            print(f"     License Number : {r['license_number']}")
        print(f"     Checked At     : {r['checked_at']}")

        if r["has_violations"]:
            vios = r.get("violations", [])
            print()
            print("     ── Fee Summary ───────────────────────────────────────")
            print(f"     Total Fines           : {r['fines']:>10} EGP")
            print(f"     Court Fees            : {r['court_fees']:>10} EGP")
            print(f"     Mechanization Fee     : {r['service_fees']:>10} EGP")
            print(f"     E-Appeal Fees         : {r['appeal_fees']:>10} EGP")
            if r["postal_fees"] != "0":
                print(f"     Postal Fees           : {r['postal_fees']:>10} EGP")
            print(f"     {'─' * 46}")
            print(f"     GRAND TOTAL           : {r['grand_total']:>10} EGP")

            if vios:
                print()
                print(f"     ── Violations ({len(vios)} total) ───────────────────────────")
                for i, v in enumerate(vios, 1):
                    print(f"\n     [{i:02d}]  Date      : {v.get('date', '—')}")
                    print(f"           Location  : {v.get('location', '—')}")
                    print(f"           Violation : {v.get('description', '—')}")
                    amt = v.get('fine_amount', '—')
                    lo  = v.get('min_fine', '—')
                    hi  = v.get('max_fine', '—')
                    print(f"           Fine      : {amt} EGP  (range {lo}–{hi} EGP)")
                    if v.get("photo_file"):
                        print(f"           Photo     : {v['photo_file']}")
                    elif v.get("fine_id"):
                        print(f"           Fine ID   : {v['fine_id']}")
        else:
            print(f"\n     ✅  No traffic violations found")

        if r.get("error"):
            print(f"\n     ❌  Error: {r['error']}")

        print("\n  " + "─" * (W + 2))

    # Save JSON
    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"\n  💾  Full report saved → {OUTPUT_JSON}\n")


# ────────────────────────────────────────────────────────────────────
#  HELPERS
# ────────────────────────────────────────────────────────────────────

def _save_screenshot(page: Page, path: str):
    try:
        page.screenshot(path=path, full_page=True)
        print(f"  📸  Debug screenshot: {path}")
    except Exception:
        pass


# ────────────────────────────────────────────────────────────────────
#  ENTRY POINT
# ────────────────────────────────────────────────────────────────────

def main():
    W = 68
    print("\n" + "═" * W)
    print("  🚗  Egyptian Traffic Violation Checker  |  ppo.gov.eg")
    print(f"  Checking {len(VEHICLES)} vehicle(s)...")
    print("═" * W)

    all_results = []

    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            headless=HEADLESS,
            slow_mo=SLOW_MO,
            args=[
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--disable-blink-features=AutomationControlled",
            ],
        )

        ctx = browser.new_context(
            locale="ar-EG",
            timezone_id="Africa/Cairo",
            viewport={"width": 1280, "height": 900},
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/122.0.0.0 Safari/537.36"
            ),
            extra_http_headers={"Accept-Language": "ar-EG,ar;q=0.9,en;q=0.8"},
        )

        page = ctx.new_page()
        page.set_default_timeout(TIMEOUT)

        for i, vehicle in enumerate(VEHICLES):
            result = check_vehicle(page, vehicle)
            all_results.append(result)
            if i < len(VEHICLES) - 1:
                print("\n  Waiting 3 seconds before next vehicle...")
                time.sleep(3)

        if not HEADLESS:
            print("\n  Browser closes in 20 seconds...")
            time.sleep(20)

        browser.close()

    print_report(all_results)

    return 1 if any(r.get("has_violations") for r in all_results) else 0


if __name__ == "__main__":
    sys.exit(main())
