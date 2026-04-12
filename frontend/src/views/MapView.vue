<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { ChevronLeft, X, MapPin, Star, IndianRupee, Navigation } from 'lucide-vue-next'

// Fix Leaflet's broken default icon path with bundlers
delete L.Icon.Default.prototype._getIconUrl
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
    iconUrl:       'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
    shadowUrl:     'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
})

const router   = useRouter()
const mapEl    = ref(null)
const courts   = ref([])
const selected = ref(null)   // court shown in bottom sheet
const loading  = ref(true)
const locating = ref(false)

let map = null
const markers = []

const sportColor = {
    shuttle:  '#7c3aed',
    turf:     '#16a34a',
    gym:      '#dc2626',
    tennis:   '#d97706',
    cricket:  '#0891b2',
    swimming: '#2563eb',
    boxing:   '#9333ea',
    basket:   '#ea580c',
    other:    '#64748b',
}

const sportEmoji = {
    shuttle: '🏸', turf: '⚽', gym: '🏋️', tennis: '🎾',
    cricket: '🏏', swimming: '🏊', boxing: '🥊', basket: '🏀', other: '🏟️',
}

const makeIcon = (type) => L.divIcon({
    className: '',
    html: `<div style="
        background:${sportColor[type] || sportColor.other};
        width:36px;height:36px;border-radius:50% 50% 50% 0;
        transform:rotate(-45deg);border:3px solid white;
        box-shadow:0 3px 10px rgba(0,0,0,0.25);
        display:flex;align-items:center;justify-content:center;">
        <span style="transform:rotate(45deg);font-size:14px;line-height:1;">
            ${sportEmoji[type] || '🏟️'}
        </span>
    </div>`,
    iconSize: [36, 36],
    iconAnchor: [18, 36],
    popupAnchor: [0, -38],
})

const initMap = async () => {
    // Default center: India
    map = L.map(mapEl.value, { zoomControl: false }).setView([20.5937, 78.9629], 5)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 19,
    }).addTo(map)

    // Zoom control top-right
    L.control.zoom({ position: 'topright' }).addTo(map)

    // Load courts
    try {
        const res = await axios.get('/courts')
        courts.value = res.data.records || []
    } catch {
        courts.value = []
    } finally {
        loading.value = false
    }

    // Plot markers
    const plotted = courts.value.filter(c => c.lat && c.lng)
    plotted.forEach(court => {
        const m = L.marker([court.lat, court.lng], { icon: makeIcon(court.type) })
            .addTo(map)
            .bindTooltip(court.name, {
                permanent: true,
                direction: 'bottom',
                offset: [0, 6],
                className: 'court-label',
            })
            .on('click', () => { selected.value = court })
        markers.push(m)
    })

    // Fit bounds if we have plotted courts
    if (plotted.length > 0) {
        const group = L.featureGroup(markers)
        map.fitBounds(group.getBounds().pad(0.3))
    }

    // Try user location
    locateUser(false)
}

let locationMarker = null
const locateUser = (panTo = true) => {
    if (!navigator.geolocation) return
    locating.value = true
    navigator.geolocation.getCurrentPosition(
        ({ coords }) => {
            const latlng = [coords.latitude, coords.longitude]
            if (locationMarker) locationMarker.remove()
            locationMarker = L.circleMarker(latlng, {
                radius: 8, fillColor: '#2563eb', color: 'white',
                weight: 3, fillOpacity: 1,
            }).addTo(map).bindTooltip('You are here', { permanent: false })
            if (panTo) map.setView(latlng, 14)
            locating.value = false
        },
        () => { locating.value = false },
        { timeout: 8000 }
    )
}

onMounted(initMap)
onUnmounted(() => { if (map) map.remove() })

const goToCourt = (court) => {
    router.push(`/courts/${court.id}`)
}
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
                        {{ courts.filter(c => c.lat && c.lng).length }} on map
                    </span>
                    <span v-else class="ml-auto w-4 h-4 border-2 border-slate-200 border-t-primary rounded-full animate-spin"></span>
                </div>
            </div>
        </div>

        <!-- Map -->
        <div ref="mapEl" class="flex-1 w-full h-full z-0"></div>

        <!-- Locate me button -->
        <button @click="locateUser(true)"
            class="absolute bottom-6 right-4 z-[400] w-11 h-11 bg-white rounded-full shadow-lg flex items-center justify-center active:scale-95 transition-transform"
            :class="{ 'bottom-52': selected }">
            <Navigation :size="18" :class="locating ? 'text-primary animate-pulse' : 'text-slate-600'" />
        </button>

        <!-- No-location notice -->
        <div v-if="!loading && courts.length > 0 && courts.filter(c => c.lat && c.lng).length === 0"
            class="absolute bottom-6 inset-x-4 z-[400] bg-amber-50 border border-amber-200 rounded-2xl px-4 py-3 text-sm text-amber-800 font-medium text-center">
            No courts have location pins yet. Owners need to set GPS coordinates.
        </div>

        <!-- Bottom sheet — selected court -->
        <Transition
            enter-active-class="transition duration-250 ease-out"
            enter-from-class="translate-y-full opacity-0"
            enter-to-class="translate-y-0 opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="translate-y-0 opacity-100"
            leave-to-class="translate-y-full opacity-0">
            <div v-if="selected"
                class="absolute bottom-0 inset-x-0 z-[400] bg-white rounded-t-3xl shadow-2xl pb-8"
                style="box-shadow: 0 -8px 40px rgba(0,0,0,0.15);">

                <!-- Handle -->
                <div class="flex justify-center pt-3 pb-1">
                    <div class="w-10 h-1 bg-slate-200 rounded-full"></div>
                </div>

                <button @click="selected = null"
                    class="absolute top-4 right-4 w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                    <X :size="16" class="text-slate-500" />
                </button>

                <div class="px-5 pt-2">
                    <!-- Image -->
                    <div class="w-full h-36 rounded-2xl overflow-hidden bg-slate-100 mb-4">
                        <img v-if="selected.image_url" :src="selected.image_url"
                            class="w-full h-full object-cover" :alt="selected.name" />
                        <div v-else class="w-full h-full flex items-center justify-center text-4xl">
                            {{ sportEmoji[selected.type] || '🏟️' }}
                        </div>
                    </div>

                    <!-- Info -->
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
                        <button @click="goToCourt(selected)"
                            class="btn-primary px-6 py-3 text-sm">
                            Book Now
                        </button>
                    </div>
                </div>
            </div>
        </Transition>

    </div>
</template>

<style scoped>
:deep(.leaflet-container) {
    width: 100%;
    height: 100%;
    font-family: inherit;
}
</style>

<style>
/* Court name label — global so Leaflet can reach it */
.court-label {
    background: white;
    border: none !important;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15) !important;
    border-radius: 20px !important;
    padding: 3px 10px !important;
    font-size: 11px !important;
    font-weight: 700 !important;
    color: #1e293b !important;
    white-space: nowrap;
}
.court-label::before {
    display: none !important;
}
</style>
