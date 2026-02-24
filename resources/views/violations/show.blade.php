@extends('layouts.app')
@section('title', 'Violation Details')
@section('header', 'Violation Details')

@section('content')
<div class="space-y-6 mt-2">

    {{-- Header Card --}}
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
                <div class="flex items-center gap-3 mb-1">
                    <span class="text-2xl">{{ $violation->has_violations ? '⚠️' : '✅' }}</span>
                    <h2 class="text-xl font-bold text-gray-800">{{ $violation->vehicle->owner_name }}</h2>
                </div>
                <p class="text-gray-500 font-mono text-sm">Plate: {{ $violation->vehicle->plate }}</p>
                @if($violation->owner_name)
                    <p class="text-gray-500 text-sm">License Owner: {{ $violation->owner_name }}</p>
                @endif
                @if($violation->license_number)
                    <p class="text-gray-500 text-sm">License No: {{ $violation->license_number }}</p>
                @endif
                <p class="text-gray-400 text-xs mt-1">Checked: {{ $violation->checked_at->format('d/m/Y H:i') }}</p>
            </div>
            <div class="text-right">
                @if($violation->has_violations)
                    <p class="text-4xl font-bold text-red-600">{{ number_format($violation->grand_total) }}</p>
                    <p class="text-sm text-gray-500">EGP Grand Total</p>
                    <p class="text-xs text-gray-400 mt-1">{{ $violation->violations_count }} violation(s)</p>
                @else
                    <p class="text-2xl font-bold text-green-600">No Violations</p>
                    <p class="text-sm text-gray-400">Vehicle is clean ✅</p>
                @endif
            </div>
        </div>
    </div>

    @if($violation->has_violations)

    {{-- Fee Summary --}}
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <h3 class="font-semibold text-gray-700 mb-4">Fee Breakdown</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="bg-red-50 rounded-lg p-4 text-center">
                <p class="text-xs text-gray-500 mb-1">Total Fines</p>
                <p class="text-2xl font-bold text-red-600">{{ number_format($violation->fines_total) }}</p>
                <p class="text-xs text-gray-400">EGP</p>
            </div>
            <div class="bg-orange-50 rounded-lg p-4 text-center">
                <p class="text-xs text-gray-500 mb-1">Court Fees</p>
                <p class="text-2xl font-bold text-orange-600">{{ number_format($violation->court_fees) }}</p>
                <p class="text-xs text-gray-400">EGP</p>
            </div>
            <div class="bg-yellow-50 rounded-lg p-4 text-center">
                <p class="text-xs text-gray-500 mb-1">Service Fees</p>
                <p class="text-2xl font-bold text-yellow-600">{{ number_format($violation->service_fees) }}</p>
                <p class="text-xs text-gray-400">EGP</p>
            </div>
            <div class="bg-blue-50 rounded-lg p-4 text-center border-2 border-blue-200">
                <p class="text-xs text-gray-500 mb-1">Grand Total</p>
                <p class="text-2xl font-bold text-blue-700">{{ number_format($violation->grand_total) }}</p>
                <p class="text-xs text-gray-400">EGP</p>
            </div>
        </div>
    </div>

    {{-- Violations Table --}}
    <div class="bg-white rounded-xl shadow-sm border border-gray-100">
        <div class="p-5 border-b border-gray-100">
            <h3 class="font-semibold text-gray-700">Violations ({{ $violation->violations_count }} total)</h3>
        </div>
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="bg-gray-50 text-xs text-gray-500 uppercase tracking-wider">
                        <th class="text-left px-5 py-3">#</th>
                        <th class="text-left px-5 py-3">Date</th>
                        <th class="text-left px-5 py-3">Location</th>
                        <th class="text-left px-5 py-3">Violation</th>
                        <th class="text-right px-5 py-3">Min</th>
                        <th class="text-right px-5 py-3">Max</th>
                        <th class="text-right px-5 py-3 font-bold">Fine</th>
                        <th class="text-center px-5 py-3">Photo</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-50">
                    @foreach($violation->violations as $i => $v)
                        <tr class="hover:bg-gray-50 transition">
                            <td class="px-5 py-3 text-gray-400 font-mono">{{ $i + 1 }}</td>
                            <td class="px-5 py-3 text-gray-600 whitespace-nowrap">{{ $v['date'] ?? '—' }}</td>
                            <td class="px-5 py-3 text-gray-600 max-w-xs">
                                <span class="line-clamp-2" title="{{ $v['location'] ?? '' }}">
                                    {{ $v['location'] ?? '—' }}
                                </span>
                            </td>
                            <td class="px-5 py-3 text-gray-700 font-medium max-w-xs">
                                <span title="{{ $v['description'] ?? '' }}">
                                    {{ $v['description'] ?? '—' }}
                                </span>
                            </td>
                            <td class="px-5 py-3 text-right text-gray-500 font-mono">{{ $v['min_fine'] ?? '—' }}</td>
                            <td class="px-5 py-3 text-right text-gray-500 font-mono">{{ $v['max_fine'] ?? '—' }}</td>
                            <td class="px-5 py-3 text-right font-bold text-red-600 font-mono">{{ $v['fine_amount'] ?? '—' }}</td>
                            <td class="px-5 py-3 text-center">
                                @if(!empty($v['fine_id']))
                                    <a href="https://ppo.gov.eg/ppo/r/ppoportal/ppoportal/violation-form-image?p2_fineid={{ $v['fine_id'] }}"
                                       target="_blank"
                                       class="text-blue-500 hover:text-blue-700"
                                       title="View violation photo">
                                        <i class="fas fa-image"></i>
                                    </a>
                                @else
                                    <span class="text-gray-300"><i class="fas fa-image"></i></span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                </tbody>
                <tfoot>
                    <tr class="bg-red-50 font-bold">
                        <td colspan="6" class="px-5 py-3 text-right text-gray-700">Grand Total:</td>
                        <td class="px-5 py-3 text-right text-red-600 font-mono text-base">
                            {{ number_format($violation->grand_total) }} EGP
                        </td>
                        <td></td>
                    </tr>
                </tfoot>
            </table>
        </div>
    </div>

    {{-- Screenshot --}}
    @if($violation->screenshot_path)
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
        <h3 class="font-semibold text-gray-700 mb-3">Results Screenshot</h3>
        <img src="{{ Storage::url($violation->screenshot_path) }}"
             alt="Results screenshot"
             class="w-full rounded-lg border border-gray-200 shadow-sm">
    </div>
    @endif

    @endif {{-- has_violations --}}

    <div class="flex gap-3">
        <a href="{{ route('violations.index') }}"
           class="flex items-center gap-2 bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-lg text-sm transition">
            <i class="fas fa-arrow-left"></i> Back to Violations
        </a>
        <a href="{{ route('vehicles.show', $violation->vehicle) }}"
           class="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm transition">
            <i class="fas fa-car"></i> View Vehicle History
        </a>
    </div>

</div>
@endsection
