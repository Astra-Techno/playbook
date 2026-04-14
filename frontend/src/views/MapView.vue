<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { ChevronLeft, X, MapPin, Star, IndianRupee, Navigation, Lock, Bell } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'

delete L.Icon.Default.prototype._getIconUrl
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
    iconUrl:       'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
    shadowUrl:     'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
})

const router = useRouter()
const auth   = useAuthStore()
const mapEl  = ref(null)
const courts = ref([])
const places = ref([])  // ghost listings
const selected      = ref(null)   // active court
const selectedPlace = ref(null)   // ghost place
const loading   = ref(true)
const locating  = ref(false)
const requesting = ref(false)

let map = null
const markers = []

const totalOnMap = computed(() =>
    courts.value.filter(c => c.lat && c.lng).length +
    places.value.filter(p => p.lat && p.lng).length
)

const sportColor = {
    shuttle: '#7c3aed', turf: '#16a34a', gym: '#dc2626',
    tennis:  '#d97706', cricket: '#0891b2', swimming: '#2563eb',
    boxing:  '#9333ea', basket: '#ea580c', dance: '#ec4899',
    yoga:    '#8b5cf6', martial: '#b45309', golf: '#15803d',
    bowling: '#0369a1', other: '#64748b',
}
const sportEmoji = {
    shuttle: '🏸', turf: '⚽', gym: '🏋️', tennis: '🎾',
    cricket: '🏏', swimming: '🏊', boxing: '🥊', basket: '🏀',
    dance: '💃', yoga: '🧘', martial: '🥋', golf: '⛳',
    bowling: '🎳', other: '🏟️',
}

// Active court marker — coloured teardrop
const makeIcon = (type) => L.divIcon({
    className: '',
    html: `<div style="background:${sportColor[type] || sportColor.other};width:36px;height:36px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);border:3px solid white;box-shadow:0 3px 10px rgba(0,0,0,0.25);display:flex;align-items:center;justify-content:center;">
        <span style="transform:rotate(45deg);font-size:14px;line-height:1;">${sportEmoji[type] || '🏟️'}</span>
    </div>`,
    iconSize: [36, 36], iconAnchor: [18, 36], popupAnchor: [0, -38],
})

// Ghost place marker — grey teardrop with lock
const makeGhostIcon = (type) => L.divIcon({
    className: '',
    html: `<div style="background:#94a3b8;width:30px;height:30px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);border:2px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.18);display:flex;align-items:center;justify-content:center;opacity:0.75;">
        <span style="transform:rotate(45deg);font-size:11px;line-height:1;">${sportEmoji[type] || '🏟️'}</span>
    </div>`,
    iconSize: [30, 30], iconAnchor: [15, 30], popupAnchor: [0, -32],
})

const initMap = async () => {
    map = L.map(mapEl.value, { zoomControl: false }).setView([20.5937, 78.9629], 5)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors', maxZoom: 19,
    }).addTo(map)
    L.control.zoom({ position: 'topright' }).addTo(map)

    // Load courts
    try {
        const res = await axios.get('/courts')
        courts.value = res.data.records || []
    } catch { courts.value = [] }

    // Plot active court markers
    const plotted = courts.value.filter(c => c.lat && c.lng)
    plotted.forEach(court => {
        const m = L.marker([court.lat, court.lng], { icon: makeIcon(court.type), zIndexOffset: 100 })
            .addTo(map)
            .bindTooltip(court.name, { permanent: true, direction: 'bottom', offset: [0, 6], className: 'court-label' })
            .on('click', () => { selected.value = court; selectedPlace.value = null })
        markers.push(m)
    })

    if (plotted.length > 0) {
        map.fitBounds(L.featureGroup(markers).getBounds().pad(0.3))
    }

    loading.value = false

    // Get user location, then load ghost places
    locateUser(false, async (latlng) => {
        try {
            const userId = auth.user?.id ?? ''
            const res = await axios.get(`/nearby-places?lat=${latlng[0]}&lng=${latlng[1]}&user_id=${userId}`)
            places.value = res.data.places || []
            plotGhostPlaces()
        } catch { /* ghost places optional */ }
    })
}

const plotGhostPlaces = () => {
    places.value.filter(p => p.lat && p.lng).forEach(place => {
        const m = L.marker([place.lat, place.lng], { icon: makeGhostIcon(place.type), zIndexOffset: 0 })
            .addTo(map)
            .bindTooltip(place.name, { permanent: false, direction: 'bottom', offset: [0, 4], className: 'ghost-label' })
            .on('click', () => { selectedPlace.value = place; selected.value = null })
        markers.push(m)
    })
}

let locationMarker = null
const locateUser = (panTo = true, onLocated = null) => {
    if (!navigator.geolocation) return
    locating.value = true
    navigator.geolocation.getCurrentPosition(
        ({ coords }) => {
            const latlng = [coords.latitude, coords.longitude]
            if (locationMarker) locationMarker.remove()
            locationMarker = L.circleMarker(latlng, {
                radius: 8, fillColor: '#2563eb', color: 'white', weight: 3, fillOpacity: 1,
            }).addTo(map).bindTooltip('You are here', { permanent: false })
            if (panTo) map.setView(latlng, 14)
            locating.value = false
            if (onLocated) onLocated(latlng)
        },
        () => { locating.value = false },
        { timeout: 8000 }
    )
}

const requestService = async (place) => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    requesting.value = true
    try {
        await axios.post('/service-requests', { place_id: place.id, user_id: auth.user.id })
        place.user_requested = true
        place.request_count = (parseInt(place.request_count) || 0) + 1
        selectedPlace.value = { ...place }
    } catch { /* ignore */ }
    finally { requesting.value = false }
}

onMounted(initMap)
onUnmounted(() => { if (map) map.remove() })

const goToCourt = (court) => router.push(`/courts/${court.id}`)
</script>

<template>
    <div class="relative w-full h-full flex flex-col">

        <!-- Top bar -->
        <div class="absolute top-0 inset-x-0 z-[400] px-4 pt-12 pb-3 pointer-events-none">
            <div class="flex items-center gap-2 pointer-events-auto">
                <button @click="router.back()"
                    class="w-10 h-10 rounded-full bg-white shadow-md flex items-center justify-center shrink-0">
                    <ChevronLeft :size="20" :stroke-width="2.5" class="text-slate-700" />
                </button>
                <div class="flex-1 bg-white rounded-2xl shadow-md px-4 py-2.5 flex items-center gap-2">
                    <MapPin :size="15" class="text-primary shrink-0" />
                    <span class="text-sm font-semibold text-slate-700">Services near you</span>
                    <span v-if="!loading" class="ml-auto text-xs text-slate-400 font-medium">
                        {{ totalOnMap }} on map
                    </span>
                    <span v-else class="ml-auto w-4 h-4 border-2 border-slate-200 border-t-primary rounded-full animate-spin"></span>
                </div>
            </div>
        </div>

        <!-- Map -->
        <div ref="mapEl" class="flex-1 w-full h-full z-0"></div>

        <!-- Locate me -->
        <button @click="locateUser(true)"
            class="absolute bottom-6 right-4 z-[400] w-11 h-11 bg-white rounded-full shadow-lg flex items-center justify-center active:scale-95 transition-transform"
            :class="{ 'bottom-52': selected || selectedPlace }">
            <Navigation :size="18" :class="locating ? 'text-primary animate-pulse' : 'text-slate-600'" />
        </button>

        <!-- Legend -->
        <div class="absolute bottom-6 left-4 z-[400] bg-white/90 backdrop-blur-sm rounded-xl px-3 py-2 shadow-md flex items-center gap-3 text-xs font-semibold"
            :class="{ 'bottom-52': selected || selectedPlace }">
            <div class="flex items-center gap-1.5">
                <div class="w-3 h-3 rounded-full bg-primary"></div>
                <span class="text-slate-700">Active</span>
            </div>
            <div class="flex items-center gap-1.5">
                <div class="w-3 h-3 rounded-full bg-slate-400 opacity-75"></div>
                <span class="text-slate-500">Coming soon</span>
            </div>
        </div>

        <!-- Bottom sheet — active court -->
        <Transition
            enter-active-class="transition duration-250 ease-out"
            enter-from-class="translate-y-full opacity-0"
            enter-to-class="translate-y-0 opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="translate-y-0 opacity-100"
            leave-to-class="translate-y-full opacity-0">
            <div v-if="selected"
                class="absolute bottom-0 inset-x-0 z-[400] bg-white rounded-t-3xl shadow-2xl pb-8"
                style="box-shadow:0 -8px 40px rgba(0,0,0,0.15)">
                <div class="flex justify-center pt-3 pb-1">
                    <div class="w-10 h-1 bg-slate-200 rounded-full"></div>
                </div>
                <button @click="selected = null"
                    class="absolute top-4 right-4 w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                    <X :size="16" class="text-slate-500" />
                </button>
                <div class="px-5 pt-2">
                    <div class="w-full h-36 rounded-2xl overflow-hidden bg-slate-100 mb-4">
                        <img v-if="selected.image_url" :src="selected.image_url"
                            class="w-full h-full object-cover" :alt="selected.name" />
                        <div v-else class="w-full h-full flex items-center justify-center text-4xl">
                            {{ sportEmoji[selected.type] || '🏟️' }}
                        </div>
                    </div>
                    <div class="flex items-start justify-between gap-3 mb-3">
                        <div class="flex-1 min-w-0">
                            <h3 class="font-extrabold text-slate-900 text-lg leading-tight truncate">{{ selected.name }}</h3>
                            <div class="flex items-center gap-1.5 mt-1 text-sm text-slate-500">
                                <MapPin :size="13" class="text-slate-400 shrink-0" />
                                <span class="truncate">{{ selected.location || 'Location not set' }}</span>
                            </div>
                        </div>
                        <div class="flex items-center gap-1 shrink-0 bg-amber-50 px-2 py-1 rounded-lg">
                            <Star :size="13" class="text-amber-400 fill-amber-400" />
                            <span class="text-xs font-bold text-amber-700">4.8</span>
                        </div>
                    </div>
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-xs text-slate-400 font-medium">Starting at</p>
                            <div class="flex items-center gap-0.5">
                                <IndianRupee :size="16" class="text-primary" :stroke-width="2.5" />
                                <span class="text-xl font-extrabold text-slate-900">{{ selected.hourly_rate }}</span>
                                <span class="text-sm text-slate-400 font-medium">/hr</span>
                            </div>
                        </div>
                        <button @click="goToCourt(selected)" class="btn-primary px-6 py-3 text-sm">
                            Book Now
                        </button>
                    </div>
                </div>
            </div>
        </Transition>

        <!-- Bottom sheet — ghost place -->
        <Transition
            enter-active-class="transition duration-250 ease-out"
            enter-from-class="translate-y-full opacity-0"
            enter-to-class="translate-y-0 opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="translate-y-0 opacity-100"
            leave-to-class="translate-y-full opacity-0">
            <div v-if="selectedPlace"
                class="absolute bottom-0 inset-x-0 z-[400] bg-white rounded-t-3xl shadow-2xl pb-8"
                style="box-shadow:0 -8px 40px rgba(0,0,0,0.15)">
                <div class="flex justify-center pt-3 pb-1">
                    <div class="w-10 h-1 bg-slate-200 rounded-full"></div>
                </div>
                <button @click="selectedPlace = null"
                    class="absolute top-4 right-4 w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                    <X :size="16" class="text-slate-500" />
                </button>
                <div class="px-5 pt-2">
                    <!-- Greyscale image with lock overlay -->
                    <div class="relative w-full h-32 rounded-2xl overflow-hidden bg-slate-100 mb-4">
                        <img v-if="selectedPlace.image_url" :src="selectedPlace.image_url"
                            class="w-full h-full object-cover grayscale opacity-60" :alt="selectedPlace.name" />
                        <div v-else class="w-full h-full flex items-center justify-center text-4xl opacity-40">
                            {{ sportEmoji[selectedPlace.type] || '🏟️' }}
                        </div>
                        <div class="absolute inset-0 flex items-center justify-center">
                            <div class="bg-white/80 backdrop-blur-sm rounded-full px-3 py-1.5 flex items-center gap-1.5">
                                <Lock :size="13" class="text-slate-500" />
                                <span class="text-xs font-bold text-slate-600">Not yet on KoCourt</span>
                            </div>
                        </div>
                    </div>

                    <h3 class="font-extrabold text-slate-900 text-lg leading-tight mb-1">{{ selectedPlace.name }}</h3>
                    <div class="flex items-center gap-1.5 mb-1 text-sm text-slate-500">
                        <MapPin :size="13" class="text-slate-400 shrink-0" />
                        <span class="truncate">{{ selectedPlace.address }}</span>
                    </div>
                    <p v-if="selectedPlace.request_count > 0" class="text-xs text-slate-400 mb-4">
                        {{ selectedPlace.request_count }} {{ selectedPlace.request_count === 1 ? 'person' : 'people' }} interested
                    </p>
                    <p v-else class="text-xs text-slate-400 mb-4">Be the first to request this venue</p>

                    <button
                        @click="requestService(selectedPlace)"
                        :disabled="selectedPlace.user_requested || requesting"
                        class="w-full py-3.5 rounded-2xl font-bold text-sm flex items-center justify-center gap-2 transition-all"
                        :class="selectedPlace.user_requested
                            ? 'bg-slate-100 text-slate-400 cursor-default'
                            : 'bg-primary text-white active:scale-95'">
                        <span v-if="requesting" class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                        <Bell v-else-if="!selectedPlace.user_requested" :size="15" />
                        <span>{{ selectedPlace.user_requested ? 'Interest Registered ✓' : 'Request This Venue' }}</span>
                    </button>
                </div>
            </div>
        </Transition>

    </div>
</template>

<style scoped>
:deep(.leaflet-container) { width: 100%; height: 100%; font-family: inherit; }
</style>

<style>
.court-label {
    background: white; border: none !important;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15) !important;
    border-radius: 20px !important; padding: 3px 10px !important;
    font-size: 11px !important; font-weight: 700 !important;
    color: #1e293b !important; white-space: nowrap;
}
.court-label::before { display: none !important; }
.ghost-label {
    background: #f1f5f9; border: none !important;
    box-shadow: 0 2px 6px rgba(0,0,0,0.10) !important;
    border-radius: 20px !important; padding: 3px 10px !important;
    font-size: 10px !important; font-weight: 600 !important;
    color: #94a3b8 !important; white-space: nowrap;
}
.ghost-label::before { display: none !important; }
</style>
