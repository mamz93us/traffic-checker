<?php

namespace App\Http\Controllers;

use App\Models\Vehicle;
use App\Models\ViolationCheck;
use Illuminate\Http\Request;

class VehicleController extends Controller
{
    public function index()
    {
        $vehicles = Vehicle::with('latestCheck')->orderBy('owner_name')->paginate(20);
        return view('vehicles.index', compact('vehicles'));
    }

    public function create()
    {
        return view('vehicles.form', ['vehicle' => new Vehicle]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'owner_name'       => 'required|string|max:150',
            'letter_1'         => 'required|string|max:2',
            'letter_2'         => 'required|string|max:2',
            'letter_3'         => 'nullable|string|max:2',
            'plate_numbers'    => 'required|string|max:4',
            'national_id'      => 'required|digits:14',
            'phone'            => 'required|string|max:15',
            'email'            => 'nullable|email',
            'whatsapp_number'  => 'nullable|string|max:15',
            'notify_email'     => 'boolean',
            'notify_whatsapp'  => 'boolean',
            'is_active'        => 'boolean',
            'notes'            => 'nullable|string',
        ]);

        $vehicle = Vehicle::create($data);
        return redirect()->route('vehicles.show', $vehicle)->with('success', 'Vehicle added successfully');
    }

    public function show(Vehicle $vehicle)
    {
        $checks = $vehicle->checks()->latest('checked_at')->paginate(20);
        return view('vehicles.show', compact('vehicle', 'checks'));
    }

    public function edit(Vehicle $vehicle)
    {
        return view('vehicles.form', compact('vehicle'));
    }

    public function update(Request $request, Vehicle $vehicle)
    {
        $data = $request->validate([
            'owner_name'      => 'required|string|max:150',
            'letter_1'        => 'required|string|max:2',
            'letter_2'        => 'required|string|max:2',
            'letter_3'        => 'nullable|string|max:2',
            'plate_numbers'   => 'required|string|max:4',
            'national_id'     => 'required|digits:14',
            'phone'           => 'required|string|max:15',
            'email'           => 'nullable|email',
            'whatsapp_number' => 'nullable|string|max:15',
            'notify_email'    => 'boolean',
            'notify_whatsapp' => 'boolean',
            'is_active'       => 'boolean',
            'notes'           => 'nullable|string',
        ]);

        $vehicle->update($data);
        return back()->with('success', 'Vehicle updated');
    }

    public function destroy(Vehicle $vehicle)
    {
        $vehicle->delete();
        return redirect()->route('vehicles.index')->with('success', 'Vehicle removed');
    }
}
