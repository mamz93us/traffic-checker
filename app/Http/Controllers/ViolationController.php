<?php

namespace App\Http\Controllers;

use App\Models\ViolationCheck;

class ViolationController extends Controller
{
    public function index()
    {
        $checks = ViolationCheck::with('vehicle')
            ->where('has_violations', true)
            ->latest('checked_at')
            ->paginate(20);

        return view('violations.index', compact('checks'));
    }

    public function show(ViolationCheck $violation)
    {
        $violation->load('vehicle');
        return view('violations.show', compact('violation'));
    }
}
