@extends('layouts.app')
@section('title', 'Vehicles')
@section('header', 'Vehicles')
@section('content')
<div class="space-y-4 mt-2">
    <div class="flex justify-between items-center">
        <p class="text-gray-500 text-sm">{{ $vehicles->total() }} vehicle(s) registered</p>
        <a href="{{ route('vehicles.create') }}" class="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition">
            <i class="fas fa-plus"></i> Add Vehicle
        </a>
    </div>
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
            <thead><tr class="bg-gray-50 text-xs text-gray-500 uppercase">
                <th class="text-left px-5 py-3">Owner</th>
                <th class="text-left px-5 py-3">Plate</th>
                <th class="text-left px-5 py-3">Latest Check</th>
                <th class="text-left px-5 py-3">Status</th>
                <th class="text-left px-5 py-3">Notifications</th>
                <th class="text-right px-5 py-3">Actions</th>
            </tr></thead>
            <tbody class="divide-y divide-gray-50">
            @forelse($vehicles as $v)
                @php $latest = $v->latestCheck; @endphp
                <tr class="hover:bg-gray-50">
                    <td class="px-5 py-3 font-medium text-gray-800">{{ $v->owner_name }}</td>
                    <td class="px-5 py-3 font-mono text-gray-600">{{ $v->plate }}</td>
                    <td class="px-5 py-3 text-gray-500">{{ $latest?->checked_at?->diffForHumans() ?? 'Never' }}</td>
                    <td class="px-5 py-3">
                        @if($latest?->has_violations)
                            <span class="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full font-semibold">⚠️ {{ $latest->violations_count }} violations</span>
                        @elseif($latest)
                            <span class="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-semibold">✅ Clean</span>
                        @else
                            <span class="text-xs text-gray-400">—</span>
                        @endif
                    </td>
                    <td class="px-5 py-3 text-gray-500 text-xs">
                        @if($v->notify_email) 📧 @endif
                        @if($v->notify_whatsapp) 📱 @endif
                    </td>
                    <td class="px-5 py-3 text-right">
                        <div class="flex justify-end gap-2">
                            <form method="POST" action="{{ route('check.now') }}" class="inline">
                                @csrf <input type="hidden" name="vehicle_id" value="{{ $v->id }}">
                                <button class="text-blue-500 hover:text-blue-700 text-xs px-2 py-1 border border-blue-200 rounded transition" title="Check now"><i class="fas fa-rotate-right"></i> Check</button>
                            </form>
                            <a href="{{ route('vehicles.show', $v) }}" class="text-gray-500 hover:text-gray-700 text-xs px-2 py-1 border border-gray-200 rounded transition">History</a>
                            <a href="{{ route('vehicles.edit', $v) }}" class="text-yellow-500 hover:text-yellow-700 text-xs px-2 py-1 border border-yellow-200 rounded transition">Edit</a>
                        </div>
                    </td>
                </tr>
            @empty
                <tr><td colspan="6" class="px-5 py-12 text-center text-gray-400">No vehicles yet. <a href="{{ route('vehicles.create') }}" class="text-blue-600 hover:underline">Add one</a></td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    <div>{{ $vehicles->links() }}</div>
</div>
@endsection
