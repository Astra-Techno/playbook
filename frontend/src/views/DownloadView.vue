<template>
  <div class="min-h-screen bg-gradient-to-b from-gray-50 to-white">
    <div class="page-gutter py-8">
      <!-- Hero -->
      <div class="text-center mb-10">
        <img src="/logo.png" alt="KoCourt" class="w-20 h-20 mx-auto mb-4 rounded-2xl shadow-lg" />
        <h1 class="text-2xl font-black text-gray-900">Get KoCourt</h1>
        <p class="text-sm text-gray-500 mt-2 max-w-xs mx-auto">
          Book sports courts, find players, and manage venues — all in one app.
        </p>
      </div>

      <!-- Player App -->
      <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 mb-4">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m16 12-4-4-4 4"/><path d="M12 16V8"/></svg>
          </div>
          <div>
            <h2 class="text-base font-bold text-gray-900">KoCourt Player</h2>
            <p class="text-xs text-gray-500">Book courts & find matches</p>
          </div>
        </div>

        <!-- Android -->
        <a :href="playerApkUrl" class="flex items-center gap-3 w-full p-3 rounded-xl bg-gray-900 text-white mb-3 hover:bg-gray-800 transition-colors">
          <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M17.523 2.145a.535.535 0 0 0-.741.165l-1.64 2.76A8.3 8.3 0 0 0 12 4.4a8.3 8.3 0 0 0-3.142.67L7.218 2.31a.535.535 0 1 0-.906.575l1.58 2.66A7.5 7.5 0 0 0 4 11.52h16A7.5 7.5 0 0 0 16.108 5.545l1.58-2.66a.535.535 0 0 0-.165-.74M8.5 9.52a.75.75 0 1 1 0-1.5.75.75 0 0 1 0 1.5m7 0a.75.75 0 1 1 0-1.5.75.75 0 0 1 0 1.5M4 12.52h1v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7h1a1 1 0 0 0 1-1v-0H3v0a1 1 0 0 0 1 1"/></svg>
          <div>
            <div class="text-xs opacity-70">Download for</div>
            <div class="text-sm font-bold">Android</div>
          </div>
        </a>

        <!-- iOS -->
        <div v-if="testFlightPlayerUrl" >
          <a :href="testFlightPlayerUrl" target="_blank" class="flex items-center gap-3 w-full p-3 rounded-xl bg-blue-600 text-white hover:bg-blue-500 transition-colors">
            <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z"/></svg>
            <div>
              <div class="text-xs opacity-70">Download on</div>
              <div class="text-sm font-bold">TestFlight (iOS)</div>
            </div>
          </a>
        </div>
        <div v-else class="flex items-center gap-3 w-full p-3 rounded-xl bg-gray-100 text-gray-400">
          <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z"/></svg>
          <div>
            <div class="text-xs">iOS</div>
            <div class="text-sm font-semibold">Coming soon</div>
          </div>
        </div>
      </div>

      <!-- Owner App -->
      <div class="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 mb-6">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-secondary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9h18v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9Z"/><path d="m3 9 2.45-4.9A2 2 0 0 1 7.24 3h9.52a2 2 0 0 1 1.8 1.1L21 9"/><path d="M12 3v6"/></svg>
          </div>
          <div>
            <h2 class="text-base font-bold text-gray-900">KoCourt Owner</h2>
            <p class="text-xs text-gray-500">Manage your venues & earnings</p>
          </div>
        </div>

        <!-- Android -->
        <a :href="ownerApkUrl" class="flex items-center gap-3 w-full p-3 rounded-xl bg-gray-900 text-white mb-3 hover:bg-gray-800 transition-colors">
          <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M17.523 2.145a.535.535 0 0 0-.741.165l-1.64 2.76A8.3 8.3 0 0 0 12 4.4a8.3 8.3 0 0 0-3.142.67L7.218 2.31a.535.535 0 1 0-.906.575l1.58 2.66A7.5 7.5 0 0 0 4 11.52h16A7.5 7.5 0 0 0 16.108 5.545l1.58-2.66a.535.535 0 0 0-.165-.74M8.5 9.52a.75.75 0 1 1 0-1.5.75.75 0 0 1 0 1.5m7 0a.75.75 0 1 1 0-1.5.75.75 0 0 1 0 1.5M4 12.52h1v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7h1a1 1 0 0 0 1-1v-0H3v0a1 1 0 0 0 1 1"/></svg>
          <div>
            <div class="text-xs opacity-70">Download for</div>
            <div class="text-sm font-bold">Android</div>
          </div>
        </a>

        <!-- iOS -->
        <div v-if="testFlightOwnerUrl">
          <a :href="testFlightOwnerUrl" target="_blank" class="flex items-center gap-3 w-full p-3 rounded-xl bg-blue-600 text-white hover:bg-blue-500 transition-colors">
            <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z"/></svg>
            <div>
              <div class="text-xs opacity-70">Download on</div>
              <div class="text-sm font-bold">TestFlight (iOS)</div>
            </div>
          </a>
        </div>
        <div v-else class="flex items-center gap-3 w-full p-3 rounded-xl bg-gray-100 text-gray-400">
          <svg class="w-7 h-7 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z"/></svg>
          <div>
            <div class="text-xs">iOS</div>
            <div class="text-sm font-semibold">Coming soon</div>
          </div>
        </div>
      </div>

      <!-- Device detection hint -->
      <div v-if="isIOS" class="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6">
        <p class="text-xs text-amber-800 font-medium">
          You're on an iPhone. The Android APK won't work on your device. iOS version is coming soon via TestFlight.
          For now, you can use <a href="/" class="underline font-bold">kocourt.com</a> directly from Safari.
        </p>
      </div>

      <!-- Install instructions -->
      <div class="bg-gray-50 rounded-xl p-4 mb-6">
        <h3 class="text-xs font-bold text-gray-600 uppercase tracking-wider mb-3">Android Install Steps</h3>
        <ol class="text-xs text-gray-600 space-y-2 list-decimal list-inside">
          <li>Tap the <strong>Download for Android</strong> button above</li>
          <li>Open the downloaded <code class="bg-gray-200 px-1 rounded">.apk</code> file</li>
          <li>If prompted, allow "Install from unknown sources" in Settings</li>
          <li>Tap <strong>Install</strong> and open the app</li>
        </ol>
      </div>

      <!-- Web option -->
      <div class="text-center pb-8">
        <p class="text-xs text-gray-400 mb-2">Or use the web version</p>
        <a href="/" class="text-sm font-bold text-primary underline underline-offset-4">Open kocourt.com</a>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const playerApkUrl = '/downloads/kocourt-player.apk'
const ownerApkUrl = '/downloads/kocourt-owner.apk'

// These will be set once Apple Developer + TestFlight is ready
const testFlightPlayerUrl = null
const testFlightOwnerUrl = null

const isIOS = computed(() => /iPhone|iPad|iPod/i.test(navigator.userAgent))
</script>
