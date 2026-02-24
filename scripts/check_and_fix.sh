#!/bin/bash
# Run as root — finds where the files are and fixes everything

PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"

echo "=== Checking file locations ==="
echo ""
echo "Contents of /home/samirgroupnet/:"
ls -la /home/samirgroupnet/
echo ""
echo "Contents of /home/samirgroupnet/traffic-checker/ (if exists):"
ls -la /home/samirgroupnet/traffic-checker/ 2>/dev/null || echo "  DIRECTORY EMPTY OR MISSING"
echo ""
echo "Looking for artisan file anywhere under /home/samirgroupnet/:"
find /home/samirgroupnet/ -name "artisan" 2>/dev/null
echo ""
echo "Looking for composer.json anywhere under /home/samirgroupnet/:"
find /home/samirgroupnet/ -name "composer.json" 2>/dev/null | head -5
echo ""
echo "Contents of /root/ (where you extracted the zip):"
ls -la /root/ | head -30
echo ""
echo "Any traffic-checker folders on the system:"
find /root /home -maxdepth 4 -name "artisan" 2>/dev/null
