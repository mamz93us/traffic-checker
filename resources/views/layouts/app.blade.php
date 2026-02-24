<!DOCTYPE html>
<html lang="en" class="h-full bg-gray-100">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Traffic Checker') — ppo.gov.eg</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <style>
        [x-cloak] { display: none !important; }
        .sidebar-active { @apply bg-blue-700 text-white; }
    </style>
</head>
<body class="h-full" x-data="{ sidebarOpen: false }">

<!-- Mobile sidebar overlay -->
<div x-show="sidebarOpen" x-cloak class="fixed inset-0 z-40 bg-gray-600 bg-opacity-75 lg:hidden"
     @click="sidebarOpen = false"></div>

<!-- Sidebar -->
<div class="fixed inset-y-0 left-0 z-50 w-64 bg-blue-900 transform transition-transform duration-200 ease-in-out"
     :class="sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'">

    <div class="flex items-center h-16 px-6 bg-blue-950">
        <i class="fas fa-car-side text-yellow-400 text-xl mr-3"></i>
        <span class="text-white font-bold text-lg">Traffic Checker</span>
    </div>

    <nav class="mt-6 px-3">
        <a href="{{ route('dashboard') }}"
           class="flex items-center px-3 py-2.5 mb-1 rounded-lg text-blue-100 hover:bg-blue-700 transition
                  {{ request()->routeIs('dashboard') ? 'bg-blue-700 text-white' : '' }}">
            <i class="fas fa-gauge-high w-5 mr-3"></i> Dashboard
        </a>
        <a href="{{ route('vehicles.index') }}"
           class="flex items-center px-3 py-2.5 mb-1 rounded-lg text-blue-100 hover:bg-blue-700 transition
                  {{ request()->routeIs('vehicles.*') ? 'bg-blue-700 text-white' : '' }}">
            <i class="fas fa-car w-5 mr-3"></i> Vehicles
        </a>
        <a href="{{ route('violations.index') }}"
           class="flex items-center px-3 py-2.5 mb-1 rounded-lg text-blue-100 hover:bg-blue-700 transition
                  {{ request()->routeIs('violations.*') ? 'bg-blue-700 text-white' : '' }}">
            <i class="fas fa-triangle-exclamation w-5 mr-3"></i> Violations
        </a>

        <div class="mt-8 border-t border-blue-700 pt-4">
            <form method="POST" action="{{ route('logout') }}">
                @csrf
                <button class="w-full flex items-center px-3 py-2.5 rounded-lg text-blue-100 hover:bg-blue-700 transition">
                    <i class="fas fa-right-from-bracket w-5 mr-3"></i> Logout
                </button>
            </form>
        </div>
    </nav>
</div>

<!-- Main content -->
<div class="lg:pl-64 flex flex-col min-h-screen">

    <!-- Top bar -->
    <header class="sticky top-0 z-30 flex items-center h-16 bg-white border-b border-gray-200 px-4 lg:px-8 shadow-sm">
        <button @click="sidebarOpen = !sidebarOpen" class="lg:hidden mr-4 text-gray-500">
            <i class="fas fa-bars text-xl"></i>
        </button>
        <h1 class="text-lg font-semibold text-gray-800">@yield('header', 'Dashboard')</h1>
        <div class="ml-auto flex items-center gap-3">
            <span class="text-sm text-gray-500">{{ now()->timezone('Africa/Cairo')->format('d/m/Y H:i') }}</span>
            <span class="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-medium">🇪🇬 Cairo Time</span>
        </div>
    </header>

    <!-- Alerts -->
    <div class="px-4 lg:px-8 mt-4">
        @if(session('success'))
            <div class="flex items-center gap-3 bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded-lg mb-4">
                <i class="fas fa-circle-check"></i>
                {{ session('success') }}
            </div>
        @endif
        @if(session('error'))
            <div class="flex items-center gap-3 bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg mb-4">
                <i class="fas fa-circle-xmark"></i>
                {{ session('error') }}
            </div>
        @endif
    </div>

    <!-- Page content -->
    <main class="flex-1 px-4 lg:px-8 pb-8">
        @yield('content')
    </main>

    <footer class="text-center text-xs text-gray-400 py-4">
        Traffic Checker &mdash; ppo.gov.eg automation
    </footer>
</div>

@stack('scripts')
</body>
</html>
