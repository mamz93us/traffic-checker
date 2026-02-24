@extends('layouts.app')
@section('title', 'Dashboard')
@section('header', 'Dashboard')

@section('content')
<div class="space-y-6 mt-2">

    {{-- ── Stat Cards ──────────────────────────────────────────── --}}
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">

        <div class="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
            <div class="flex items-center justify-between mb-3">
                <span class="text-sm font-medium text-gray-500">Active Vehicles</span>
                <span class="text-2xl">🚗</span>
            </div>
            <p class="text-3xl font-bold text-gray-800">{{ $stats['active_vehicles'] }}</p>
            <p class="text-xs text-gray-400 mt-1">{{ $stats['total_vehicles'] }} total registered</p>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
            <div class="flex items-center justify-between mb-3">
                <span class="text-sm font-medium text-gray-500">With Violations</span>
                <span class="text-2xl">⚠️</span>
            </div>
            <p class="text-3xl font-bold {{ $stats['vehicles_with_violations'] > 0 ? 'text-red-600' : 'text-green-600' }}">
                {{ $stats['vehicles_with_violations'] }}
            </p>
            <p class="text-xs text-gray-400 mt-1">Based on latest check</p>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
            <div class="flex items-center justify-between mb-3">
                <span class="text-sm font-medium text-gray-500">Checks Today</span>
                <span class="text-2xl">🔍</span>
            </div>
            <p class="text-3xl font-bold text-gray-800">{{ $stats['checks_today'] }}</p>
            <p class="text-xs text-gray-400 mt-1">{{ now()->timezone('Africa/Cairo')->format('d/m/Y') }}</p>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
            <div class="flex items-center justify-between mb-3">
                <span class="text-sm font-medium text-gray-500">Total Fines Today</span>
                <span class="text-2xl">💰</span>
            </div>
            <p class="text-3xl font-bold {{ $stats['total_fines_today'] > 0 ? 'text-red-600' : 'text-gray-800' }}">
                {{ number_format($stats['total_fines_today']) }}
            </p>
            <p class="text-xs text-gray-400 mt-1">EGP (all vehicles)</p>
        </div>

    </div>

    {{-- ── Quick Actions ────────────────────────────────────────── --}}
    <div class="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
        <h2 class="text-base font-semibold text-gray-700 mb-4">Quick Actions</h2>
        <div class="flex flex-wrap gap-3">

            {{-- Check All Now --}}
            <form method="POST" action="{{ route('check.now') }}" class="inline"
                  onsubmit="this.querySelector('button').disabled=true; this.querySelector('button').innerHTML='<i class=\'fas fa-spinner fa-spin mr-2\'></i>Checking...'">
                @csrf
                <button class="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2.5 rounded-lg text-sm font-medium transition">
                    <i class="fas fa-play"></i> Check All Vehicles Now
                </button>
            </form>

            <a href="{{ route('vehicles.create') }}"
               class="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-white px-4 py-2.5 rounded-lg text-sm font-medium transition">
                <i class="fas fa-plus"></i> Add Vehicle
            </a>

            <a href="{{ route('violations.index') }}"
               class="flex items-center gap-2 bg-red-600 hover:bg-red-700 text-white px-4 py-2.5 rounded-lg text-sm font-medium transition">
                <i class="fas fa-triangle-exclamation"></i> View All Violations
            </a>
        </div>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-6">

        {{-- ── Vehicles Status ─────────────────────────────────── --}}
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
            <div class="flex items-center justify-between p-5 border-b border-gray-100">
                <h2 class="font-semibold text-gray-700">Vehicles Status</h2>
                <a href="{{ route('vehicles.index') }}" class="text-sm text-blue-600 hover:underline">View all</a>
            </div>
            <div class="divide-y divide-gray-50">
                @forelse($vehicles as $vehicle)
                    @php $latest = $vehicle->latestCheck; @endphp
                    <div class="flex items-center px-5 py-3.5 hover:bg-gray-50 transition">
                        <div class="flex-1 min-w-0">
                            <p class="font-medium text-gray-800 text-sm truncate">{{ $vehicle->owner_name }}</p>
                            <p class="text-xs text-gray-500 font-mono">{{ $vehicle->plate }}</p>
                        </div>
                        <div class="flex items-center gap-3 ml-3">
                            @if($latest)
                                @if($latest->has_violations)
                                    <span class="text-xs bg-red-100 text-red-700 font-semibold px-2 py-0.5 rounded-full">
                                        ⚠️ {{ $latest->violations_count }} violations
                                    </span>
                                    <span class="text-xs text-red-600 font-bold">{{ number_format($latest->grand_total) }} EGP</span>
                                @else
                                    <span class="text-xs bg-green-100 text-green-700 font-semibold px-2 py-0.5 rounded-full">✅ Clean</span>
                                @endif
                                <span class="text-xs text-gray-400">{{ $latest->checked_at->diffForHumans() }}</span>
                            @else
                                <span class="text-xs text-gray-400 italic">Not checked yet</span>
                            @endif

                            {{-- Check This Vehicle Now --}}
                            <form method="POST" action="{{ route('check.now') }}" class="inline">
                                @csrf
                                <input type="hidden" name="vehicle_id" value="{{ $vehicle->id }}">
                                <button title="Check now" class="text-blue-500 hover:text-blue-700 transition">
                                    <i class="fas fa-rotate-right text-sm"></i>
                                </button>
                            </form>
                        </div>
                    </div>
                @empty
                    <div class="p-8 text-center text-gray-400">
                        <i class="fas fa-car text-3xl mb-2 block"></i>
                        No vehicles added yet.
                        <a href="{{ route('vehicles.create') }}" class="text-blue-600 hover:underline">Add one</a>
                    </div>
                @endforelse
            </div>
        </div>

        {{-- ── Recent Checks ────────────────────────────────────── --}}
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
            <div class="flex items-center justify-between p-5 border-b border-gray-100">
                <h2 class="font-semibold text-gray-700">Recent Checks</h2>
            </div>
            <div class="divide-y divide-gray-50">
                @forelse($recentChecks as $check)
                    <div class="flex items-start px-5 py-3.5 hover:bg-gray-50 transition">
                        <div class="flex-shrink-0 mt-0.5 mr-3">
                            @if($check->status === 'error')
                                <span class="text-red-500"><i class="fas fa-circle-xmark"></i></span>
                            @elseif($check->has_violations)
                                <span class="text-orange-500"><i class="fas fa-triangle-exclamation"></i></span>
                            @else
                                <span class="text-green-500"><i class="fas fa-circle-check"></i></span>
                            @endif
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="text-sm font-medium text-gray-800">{{ $check->vehicle->owner_name }}</p>
                            <p class="text-xs font-mono text-gray-500">{{ $check->vehicle->plate }}</p>
                            @if($check->has_violations)
                                <p class="text-xs text-red-600 font-medium mt-0.5">
                                    {{ $check->violations_count }} violation(s) — {{ number_format($check->grand_total) }} EGP
                                </p>
                            @elseif($check->status === 'error')
                                <p class="text-xs text-red-500 mt-0.5">{{ Str::limit($check->error_message, 50) }}</p>
                            @else
                                <p class="text-xs text-green-600 mt-0.5">No violations</p>
                            @endif
                        </div>
                        <div class="ml-3 text-right flex-shrink-0">
                            <p class="text-xs text-gray-400">{{ $check->checked_at->diffForHumans() }}</p>
                            @if($check->has_violations)
                                <a href="{{ route('violations.show', $check) }}" class="text-xs text-blue-600 hover:underline">Details →</a>
                            @endif
                        </div>
                    </div>
                @empty
                    <div class="p-8 text-center text-gray-400">
                        <i class="fas fa-clock-rotate-left text-3xl mb-2 block"></i>
                        No checks run yet. Click "Check All Vehicles Now" to start.
                    </div>
                @endforelse
            </div>
        </div>

    </div>
</div>
@endsection
