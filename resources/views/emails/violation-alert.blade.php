<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,.1); }
        .header { padding: 24px; color: white; text-align: center; background: {{ $check->has_violations ? '#dc2626' : '#16a34a' }}; }
        .header h1 { margin: 0; font-size: 22px; }
        .body { padding: 24px; }
        .stat-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #f0f0f0; }
        .stat-label { color: #6b7280; font-size: 14px; }
        .stat-value { font-weight: bold; font-size: 14px; }
        .total-box { background: #fef2f2; border: 2px solid #fca5a5; border-radius: 8px; padding: 16px; text-align: center; margin: 20px 0; }
        .total-amount { font-size: 36px; font-weight: bold; color: #dc2626; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 13px; }
        th { background: #f9fafb; text-align: left; padding: 8px 12px; border-bottom: 2px solid #e5e7eb; color: #374151; }
        td { padding: 8px 12px; border-bottom: 1px solid #f3f4f6; color: #4b5563; }
        .footer { background: #f9fafb; padding: 16px; text-align: center; font-size: 12px; color: #9ca3af; }
        .btn { display: inline-block; background: #2563eb; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; margin-top: 16px; }
    </style>
</head>
<body>
<div class="container">

    <div class="header">
        @if($check->has_violations)
            <h1>⚠️ Traffic Violations Found</h1>
        @else
            <h1>✅ No Violations Found</h1>
        @endif
        <p style="margin:8px 0 0; opacity:.9">{{ now()->timezone('Africa/Cairo')->format('d/m/Y H:i') }} — Cairo Time</p>
    </div>

    <div class="body">
        <div class="stat-row"><span class="stat-label">Vehicle Owner</span><span class="stat-value">{{ $vehicle->owner_name }}</span></div>
        <div class="stat-row"><span class="stat-label">Plate Number</span><span class="stat-value" style="font-family:monospace">{{ $vehicle->plate }}</span></div>
        @if($check->owner_name)
        <div class="stat-row"><span class="stat-label">License Owner</span><span class="stat-value">{{ $check->owner_name }}</span></div>
        @endif

        @if($check->has_violations)

        <div class="total-box">
            <p style="margin:0 0 4px;color:#6b7280;font-size:14px">Grand Total Due</p>
            <div class="total-amount">{{ number_format($check->grand_total) }} EGP</div>
            <p style="margin:4px 0 0;color:#9ca3af;font-size:12px">{{ $check->violations_count }} violation(s)</p>
        </div>

        <h3 style="margin-top:24px;color:#374151">Fee Breakdown</h3>
        <div class="stat-row"><span class="stat-label">Total Fines</span><span class="stat-value" style="color:#dc2626">{{ number_format($check->fines_total) }} EGP</span></div>
        <div class="stat-row"><span class="stat-label">Court Fees</span><span class="stat-value">{{ number_format($check->court_fees) }} EGP</span></div>
        <div class="stat-row"><span class="stat-label">Service Fees</span><span class="stat-value">{{ number_format($check->service_fees) }} EGP</span></div>
        @if($check->appeal_fees > 0)
        <div class="stat-row"><span class="stat-label">Appeal Fees</span><span class="stat-value">{{ number_format($check->appeal_fees) }} EGP</span></div>
        @endif

        @if(count($check->violations) > 0)
        <h3 style="margin-top:24px;color:#374151">Violations (showing first {{ min(10, count($check->violations)) }})</h3>
        <table>
            <thead>
                <tr>
                    <th>#</th><th>Date</th><th>Violation</th><th>Fine (EGP)</th>
                </tr>
            </thead>
            <tbody>
                @foreach(array_slice($check->violations, 0, 10) as $i => $v)
                <tr>
                    <td>{{ $i + 1 }}</td>
                    <td>{{ $v['date'] ?? '—' }}</td>
                    <td>{{ $v['description'] ?? '—' }}</td>
                    <td style="font-weight:bold;color:#dc2626">{{ $v['fine_amount'] ?? '—' }}</td>
                </tr>
                @endforeach
            </tbody>
        </table>
        @if(count($check->violations) > 10)
            <p style="color:#6b7280;font-size:13px;margin-top:8px">... and {{ count($check->violations) - 10 }} more violations</p>
        @endif
        @endif

        <div style="text-align:center;margin-top:24px">
            <a href="{{ config('app.url') }}/violations/{{ $check->id }}" class="btn">View Full Report Online →</a>
        </div>

        @else
            <div style="text-align:center;padding:32px 0">
                <div style="font-size:64px">✅</div>
                <h2 style="color:#16a34a;margin:8px 0">No traffic violations found!</h2>
                <p style="color:#6b7280">This vehicle is clean as of {{ $check->checked_at->format('d/m/Y H:i') }}</p>
            </div>
        @endif
    </div>

    <div class="footer">
        <p>This is an automated report from your Traffic Checker system.<br>
        Powered by ppo.gov.eg data • {{ config('app.name') }}</p>
    </div>

</div>
</body>
</html>
