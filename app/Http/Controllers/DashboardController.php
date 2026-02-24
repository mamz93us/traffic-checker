<?php

namespace App\Http\Controllers;

use App\Models\Vehicle;
use App\Models\ViolationCheck;
use App\Services\NotificationService;
use App\Services\PlaywrightCheckerService;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'total_vehicles'    => Vehicle::count(),
            'active_vehicles'   => Vehicle::where('is_active', true)->count(),
            'vehicles_with_violations' => ViolationCheck::where('has_violations', true)
                ->whereIn('id', ViolationCheck::latestPerVehicle()->pluck('id'))
                ->count(),
            'total_fines_today' => ViolationCheck::whereDate('checked_at', today())
                ->where('has_violations', true)
                ->sum('grand_total'),
            'checks_today'      => ViolationCheck::whereDate('checked_at', today())->count(),
        ];

        $recentChecks = ViolationCheck::with('vehicle')
            ->latest('checked_at')
            ->take(10)
            ->get();

        $vehicles = Vehicle::with('latestCheck')
            ->where('is_active', true)
            ->orderBy('owner_name')
            ->get();

        return view('dashboard.index', compact('stats', 'recentChecks', 'vehicles'));
    }

    /** Manual "Check Now" button on dashboard */
    public function checkNow(Request $request, PlaywrightCheckerService $checker, NotificationService $notifier)
    {
        $vehicleId = $request->input('vehicle_id');

        if ($vehicleId) {
            $vehicle = Vehicle::findOrFail($vehicleId);
            $check   = $checker->checkVehicle($vehicle);
            $notifier->notify($check);
            return back()->with('success', "Check completed for {$vehicle->owner_name}");
        }

        // Check all
        $vehicles = Vehicle::where('is_active', true)->get();
        foreach ($vehicles as $vehicle) {
            $check = $checker->checkVehicle($vehicle);
            $notifier->notify($check);
        }

        return back()->with('success', "All {$vehicles->count()} vehicles checked");
    }
}
