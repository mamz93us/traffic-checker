<?php

return [

    // ── Playwright / Python ───────────────────────────────────────────
    'python_bin'     => env('PYTHON_BIN',         '/usr/bin/python3'),
    'script_path'    => env('PYTHON_SCRIPT_PATH', base_path('../traffic_checker.py')),
    'check_timeout'  => env('CHECK_TIMEOUT',       180),  // seconds per vehicle

    // ── WhatsApp ──────────────────────────────────────────────────────
    'whatsapp_provider'    => env('WHATSAPP_PROVIDER',      'green_api'),
    // Green API
    'whatsapp_instance_id' => env('WHATSAPP_INSTANCE_ID',   ''),
    'whatsapp_access_token'=> env('WHATSAPP_ACCESS_TOKEN',  ''),
    // Twilio
    'twilio_account_sid'   => env('TWILIO_ACCOUNT_SID',     ''),
    'twilio_auth_token'    => env('TWILIO_AUTH_TOKEN',       ''),
    'twilio_whatsapp_from' => env('TWILIO_WHATSAPP_FROM',    'whatsapp:+14155238886'),

    // ── Schedule ──────────────────────────────────────────────────────
    'check_frequency' => env('CHECK_FREQUENCY', 'daily'),    // daily | twice_daily | weekly
    'check_time_1'    => env('CHECK_TIME_1',    '08:00'),
    'check_time_2'    => env('CHECK_TIME_2',    '20:00'),

];
