@extends('layouts.app')
@section('title', $vehicle->owner_name)
@section('header', 'Vehicle History')
@section('content')
<div class="space-y-5 mt-2">

    {{-- Vehicle Info Card --}}
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
                <h2 class="text-xl font-bold text-gray-800">{{ $vehicle->owner_name }}</h2>
                <p class="font-mono text-gray-500 mt-0.5">Plate: {{ $vehicle->plate }}</p>
                @if($vehicle->email)
                    <p class="text-sm text-gray-400 mt-0.5">📧 {{ $vehicle->email }}</p>
                @endif
                @if($vehicle->phone)
                    <p class="text-sm text-gray-400">📱 {{ $vehicle->phone }}</p>
                @endif
            </div>
            <div class="flex gap-2">
                <form method="POST" action="{{ route('check.now') }}">
                    @csrf
                    <input type="hidden" name="vehicle_id" value="{{ $vehicle->id }}">
                    <button class="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition">
                        <i class="fas fa-rotate-right"></i> Check Now
                    </button>
                </form>
                <a href="{{ route('vehicles.edit', $vehicle) }}"
                   class="flex items-center gap-2 bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-lg text-sm font-medium transition">
                    <i class="fas fa-pencil"></i> Edit
                </a>
            </div>
        </div>
    </div>

    {{-- Check History --}}
    <div class="bg-white rounded-xl shadow-sm border border-gray-100">
        <div class="p-5 border-b border-gray-100">
            <h3 class="font-semibold text-gray-700">Check History ({{ $checks->total() }} checks)</h3>
        </div>
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="bg-gray-50 text-xs text-gray-500 uppercase">
                        <th class="text-left px-5 py-3">Date / Time</th>
                        <th class="text-left px-5 py-3">Status</th>
                        <th class="text-right px-5 py-3">Violations</th>
                        <th class="text-right px-5 py-3">Grand Total</th>
                        <th class="text-center px-5 py-3">Notified</th>
                        <th class="text-right px-5 py-3">Details</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-50">
                    @forelse($checks as $c)
                        <tr class="hover:bg-gray-50 transition">
                            <td class="px-5 py-3 text-gray-600">
                                {{ $c->checked_at->format('d/m/Y H:i') }}
                                <span class="text-xs text-gray-400 block">{{ $c->checked_at->diffForHumans() }}</span>
                            </td>
                            <td class="px-5 py-3">
                                @if($c->status === 'error')
                                    <span class="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full">❌ Error</span>
                                @elseif($c->has_violations)
                                    <span class="text-xs bg-orange-100 text-orange-700 px-2 py-0.5 rounded-full font-semibold">⚠️ Violations</span>
                                @else
                                    <span class="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-semibold">✅ Clean</span>
                                @endif
                            </td>
                            <td class="px-5 py-3 text-right text-gray-700">
                                {{ $c->has_violations ? $c->violations_count : '—' }}
                            </td>
                            <td class="px-5 py-3 text-right font-bold {{ $c->has_violations ? 'text-red-600' : 'text-gray-400' }}">
                                {{ $c->has_violations ? number_format($c->grand_total) . ' EGP' : '—' }}
                            </td>
                            <td class="px-5 py-3 text-center text-sm">
                                {{ $c->notified_email ? '📧' : '' }}
                                {{ $c->notified_whatsapp ? '📱' : '' }}
                                @if(!$c->notified_email && !$c->notified_whatsapp)
                                    <span class="text-gray-300 text-xs">none</span>
                                @endif
                            </td>
                            <td class="px-5 py-3 text-right">
                                @if($c->has_violations)
                                    <a href="{{ route('violations.show', $c) }}"
                                       class="text-blue-600 hover:text-blue-800 text-xs border border-blue-200 px-2 py-1 rounded transition">
                                        View →
                                    </a>
                                @else
                                    <span class="text-gray-300 text-xs">—</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-5 py-10 text-center text-gray-400">
                                No checks run yet for this vehicle.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        @if($checks->hasPages())
            <div class="px-5 py-4 border-t border-gray-100">
                {{ $checks->links() }}
            </div>
        @endif
    </div>

    <a href="{{ route('vehicles.index') }}"
       class="inline-flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition">
        <i class="fas fa-arrow-left"></i> Back to Vehicles
    </a>

</div>
@endsection
