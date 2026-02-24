<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\VehicleController;
use App\Http\Controllers\ViolationController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth'])->group(function () {

    Route::get('/',          [DashboardController::class, 'index'])->name('dashboard');
    Route::post('/check-now', [DashboardController::class, 'checkNow'])->name('check.now');

    Route::resource('vehicles',  VehicleController::class);

    Route::get('/violations',         [ViolationController::class, 'index'])->name('violations.index');
    Route::get('/violations/{violation}', [ViolationController::class, 'show'])->name('violations.show');

});

// Auth routes (Laravel Breeze / Fortify handles these)
require __DIR__ . '/auth.php';
