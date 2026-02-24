@extends('layouts.app')
@section('title', 'Violations')
@section('header', 'All Violations')
@section('content')
<div class="space-y-4 mt-2">
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
            <thead><tr class="bg-gray-50 text-xs text-gray-500 uppercase">
                <th class="text-left px-5 py-3">Vehicle</th>
                <th class="text-left px-5 py-3">Plate</th>
                <th class="text-right px-5 py-3">Violations</th>
                <th class="text-right px-5 py-3">Grand Total</th>
                <th class="text-left px-5 py-3">Checked</th>
                <th class="text-center px-5 py-3">Notified</th>
                <th class="text-right px-5 py-3">Actions</th>
            </tr></thead>
            <tbody class="divide-y divide-gray-50">
            @forelse($checks as $c)
                <tr class="hover:bg-gray-50">
                    <td class="px-5 py-3 font-medium text-gray-800">{{ $c->vehicle->owner_name }}</td>
                    <td class="px-5 py-3 font-mono text-gray-600">{{ $c->vehicle->plate }}</td>
                    <td class="px-5 py-3 text-right text-orange-600 font-semibold">{{ $c->violations_count }}</td>
                    <td class="px-5 py-3 text-right text-red-600 font-bold">{{ number_format($c->grand_total) }} EGP</td>
                    <td class="px-5 py-3 text-gray-500 text-xs">{{ $c->checked_at->format('d/m/Y H:i') }}</td>
                    <td class="px-5 py-3 text-center text-xs">
                        {{ $c->notified_email ? '📧' : '' }} {{ $c->notified_whatsapp ? '📱' : '' }}
                        @if(!$c->notified_email && !$c->notified_whatsapp) <span class="text-gray-300">—</span> @endif
                    </td>
                    <td class="px-5 py-3 text-right">
                        <a href="{{ route('violations.show', $c) }}" class="text-blue-600 hover:text-blue-800 text-xs border border-blue-200 px-2 py-1 rounded transition">Details →</a>
                    </td>
                </tr>
            @empty
                <tr><td colspan="7" class="px-5 py-12 text-center text-gray-400">No violations found yet ✅</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    <div>{{ $checks->links() }}</div>
</div>
@endsection
