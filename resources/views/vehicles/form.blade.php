@extends('layouts.app')
@section('title', isset($vehicle->id) ? 'Edit Vehicle' : 'Add Vehicle')
@section('header', isset($vehicle->id) ? 'Edit Vehicle' : 'Add Vehicle')
@section('content')
<div class="max-w-2xl mt-2">
    <form method="POST" action="{{ isset($vehicle->id) ? route('vehicles.update', $vehicle) : route('vehicles.store') }}" class="bg-white rounded-xl shadow-sm border border-gray-100 p-6 space-y-5">
        @csrf
        @if(isset($vehicle->id)) @method('PUT') @endif

        <div class="grid grid-cols-2 gap-4">
            <div class="col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Owner Name</label>
                <input name="owner_name" value="{{ old('owner_name', $vehicle->owner_name) }}" required class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent">
            </div>

            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Letter 1 (Arabic)</label>
                <input name="letter_1" value="{{ old('letter_1', $vehicle->letter_1) }}" maxlength="2" required class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-center text-xl" dir="rtl">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Letter 2 (Arabic)</label>
                <input name="letter_2" value="{{ old('letter_2', $vehicle->letter_2) }}" maxlength="2" required class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-center text-xl" dir="rtl">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Letter 3 (Arabic, optional)</label>
                <input name="letter_3" value="{{ old('letter_3', $vehicle->letter_3) }}" maxlength="2" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-center text-xl" dir="rtl">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Plate Numbers</label>
                <input name="plate_numbers" value="{{ old('plate_numbers', $vehicle->plate_numbers) }}" maxlength="4" required class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">National ID (14 digits)</label>
                <input name="national_id" value="{{ old('national_id', $vehicle->national_id) }}" maxlength="14" required class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Phone Number</label>
                <input name="phone" value="{{ old('phone', $vehicle->phone) }}" required class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email (for notifications)</label>
                <input type="email" name="email" value="{{ old('email', $vehicle->email) }}" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">WhatsApp Number (if different)</label>
                <input name="whatsapp_number" value="{{ old('whatsapp_number', $vehicle->whatsapp_number) }}" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono">
            </div>
        </div>

        <div class="border-t pt-4 space-y-2">
            <p class="text-sm font-medium text-gray-700 mb-2">Notification Preferences</p>
            <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
                <input type="checkbox" name="notify_email" value="1" {{ old('notify_email', $vehicle->notify_email ?? true) ? 'checked' : '' }} class="rounded">
                Send email alerts when violations found
            </label>
            <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
                <input type="checkbox" name="notify_whatsapp" value="1" {{ old('notify_whatsapp', $vehicle->notify_whatsapp ?? true) ? 'checked' : '' }} class="rounded">
                Send WhatsApp alerts when violations found
            </label>
            <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
                <input type="checkbox" name="is_active" value="1" {{ old('is_active', $vehicle->is_active ?? true) ? 'checked' : '' }} class="rounded">
                Active (include in automated daily checks)
            </label>
        </div>

        <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
            <textarea name="notes" rows="2" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm">{{ old('notes', $vehicle->notes) }}</textarea>
        </div>

        @if($errors->any())
            <div class="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-700">
                <ul class="list-disc list-inside space-y-1">
                    @foreach($errors->all() as $e) <li>{{ $e }}</li> @endforeach
                </ul>
            </div>
        @endif

        <div class="flex gap-3 pt-2">
            <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg text-sm font-medium transition">
                {{ isset($vehicle->id) ? 'Update Vehicle' : 'Add Vehicle' }}
            </button>
            <a href="{{ route('vehicles.index') }}" class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-6 py-2 rounded-lg text-sm font-medium transition">Cancel</a>
        </div>
    </form>
</div>
@endsection
