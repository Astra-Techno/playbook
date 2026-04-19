<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import {
    MapPin, Clock, Loader2, ChevronRight, IndianRupee, Star, Navigation,
} from 'lucide-vue-next'
import { useToastStore } from '../stores/toast'

const route  = useRoute()
const router = useRouter()
const toast  = useToastStore()

const todayStr = () => {
    const d = new Date()
    return d.toISOString().slice(0, 10)
}

const dateStr     = ref(route.query.date || todayStr())
const timeStr     = ref(normalizeTimeQuery(route.query.start) || defaultTime())
const durationMin = ref(Number(route.query.duration) || 60)
const radiusKm    = ref(25)

const lat = ref(route.query.lat ? parseFloat(route.query.lat) : null)
const lng = ref(route.query.lng ? parseFloat(route.query.lng) : null)
const locating = ref(false)

const records   = ref([])
const loading   = ref(false)
const windowInfo = ref(null)

function normalizeTimeQuery(q) {
    if (!q || typeof q !== 'string') return ''
    if (/^\d{1,2}:\d{2}$/.test(q)) return q.length === 5 ? q : q
    return ''
}

function defaultTime() {
    const d = new Date()
    d.setMinutes(Math.ceil(d.getMinutes() / 15) * 15)
    d.setSeconds(0, 0)
    const h = String(d.getHours()).padStart(2, '0')
    const m = String(d.getMinutes()).padStart(2, '0')
    return `${h}:${m}`
}

const durationOptions = [
    { v: 30, label: '30 min' },
    { v: 60, label: '1 hour' },
    { v: 90, label: '1.5 hours' },
    { v: 120, label: '2 hours' },
]

const hasCoords = computed(() => lat.value != null && lng.value != null && !Number.isNaN(lat.value) && !Number.isNaN(lng.value))

const fetchAvailable = async () => {
    if (!hasCoords.value) {
        records.value = []
        return
    }
    const start = timeStr.value.length === 5 ? timeStr.value : timeStr.value.slice(0, 5)
    loading.value = true
    try {
        const res = await axios.get('/courts/available-at', {
            params: {
                date: dateStr.value,
                start,
                duration_minutes: durationMin.value,
                lat: lat.value,
                lng: lng.value,
                radius: radiusKm.value,
            },
        })
        records.value   = res.data.records || []
        windowInfo.value = res.data.window || null
    } catch (e) {
        records.value = []
        toast.error(e.response?.data?.message || 'Could not load availability')
    } finally {
        loading.value = false
    }
}

const useMyLocation = () => {
    if (!navigator.geolocation) {
        toast.error('Location not supported on this device')
        return
    }
    locating.value = true
    navigator.geolocation.getCurrentPosition(
        (pos) => {
            lat.value = pos.coords.latitude
            lng.value = pos.coords.longitude
            locating.value = false
            fetchAvailable()
        },
        () => {
            locating.value = false
            toast.error('Could not get your location')
        },
        { enableHighAccuracy: true, timeout: 12000 }
    )
}

watch([dateStr, timeStr, durationMin, lat, lng, radiusKm], () => {
    if (hasCoords.value) fetchAvailable()
})

onMounted(async () => {
    if (!hasCoords.value) {
        useMyLocation()
    } else {
        await fetchAvailable()
    }
})

const slotLabel = computed(() => {
    if (!windowInfo.value?.start) return ''
    const s = new Date(windowInfo.value.start.replace(' ', 'T'))
    return s.toLocaleString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true })
})
</script>

<template>
    <Teleport to="#header-subject">Find courts</Teleport>
    <Teleport to="#header-subtitle">Available at this time</Teleport>

    <div class="min-h-full bg-slate-50 px-4 py-4 space-y-4 pb-6">
        <p class="text-xs text-slate-500 leading-relaxed">
            Venues near you with at least one court or space free for your chosen window (bookings + blocks considered).
        </p>

        <div class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 space-y-3 shadow-sm">
            <div class="grid grid-cols-2 gap-3">
                <label class="block col-span-2">
                    <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Date</span>
                    <input v-model="dateStr" type="date" class="input-field mt-1 text-sm py-2.5" />
                </label>
                <label class="block">
                    <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Start</span>
                    <input v-model="timeStr" type="time" class="input-field mt-1 text-sm py-2.5" />
                </label>
                <label class="block">
                    <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Duration</span>
                    <select v-model.number="durationMin" class="input-field mt-1 text-sm py-2.5">
                        <option v-for="o in durationOptions" :key="o.v" :value="o.v">{{ o.label }}</option>
                    </select>
                </label>
            </div>

            <button
                type="button"
                @click="useMyLocation"
                :disabled="locating"
                class="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-primary/10 text-primary font-bold text-sm active:scale-[0.98] transition-transform disabled:opacity-50">
                <Loader2 v-if="locating" :size="16" class="animate-spin" />
                <Navigation v-else :size="16" />
                {{ locating ? 'Getting location…' : 'Use my location' }}
            </button>

            <p v-if="hasCoords" class="text-[10px] text-slate-400 font-mono">
                {{ lat?.toFixed(4) }}, {{ lng?.toFixed(4) }} · {{ radiusKm }} km
            </p>
        </div>

        <div v-if="slotLabel" class="flex items-center gap-2 text-sm text-slate-600">
            <Clock :size="16" class="text-primary shrink-0" />
            <span>{{ slotLabel }} · {{ durationMin }} min</span>
        </div>

        <div v-if="loading" class="space-y-3">
            <div v-for="i in 4" :key="i" class="bg-white rounded-2xl h-20 animate-pulse ring-1 ring-slate-100" />
        </div>

        <div v-else-if="!hasCoords" class="text-center py-12 text-slate-500 text-sm">
            Turn on location to see venues with free slots near you.
        </div>

        <div v-else-if="!records.length" class="text-center py-12 px-4">
            <MapPin :size="36" class="mx-auto text-slate-300 mb-3" />
            <p class="font-bold text-slate-700">No available venues in range</p>
            <p class="text-sm text-slate-400 mt-1">Try another time, longer radius, or a different area.</p>
        </div>

        <div v-else class="space-y-2">
            <button
                v-for="c in records"
                :key="c.id"
                type="button"
                @click="router.push(`/courts/${c.id}`)"
                class="w-full bg-white rounded-2xl p-4 ring-1 ring-slate-100 flex items-center gap-3 text-left shadow-sm active:scale-[0.99] transition-transform">
                <div class="w-14 h-14 rounded-xl bg-slate-100 shrink-0 overflow-hidden">
                    <img v-if="c.image_url" :src="c.image_url" class="w-full h-full object-cover" alt="" />
                    <div v-else class="w-full h-full flex items-center justify-center text-slate-300">
                        <MapPin :size="22" />
                    </div>
                </div>
                <div class="flex-1 min-w-0">
                    <p class="font-bold text-slate-900 truncate">{{ c.name }}</p>
                    <p class="text-xs text-slate-500 truncate">{{ c.location || c.type }}</p>
                    <div class="flex items-center gap-2 mt-1 flex-wrap">
                        <span v-if="c.distance_km != null" class="text-[10px] font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-full">
                            {{ c.distance_km }} km
                        </span>
                        <span v-if="c.avg_rating != null" class="text-[10px] font-bold text-amber-700 flex items-center gap-0.5">
                            <Star :size="10" class="fill-amber-400 text-amber-400" /> {{ c.avg_rating }}
                        </span>
                        <span class="text-[10px] font-bold text-slate-600 flex items-center gap-0.5">
                            <IndianRupee :size="10" />{{ c.hourly_rate }}/hr
                        </span>
                    </div>
                </div>
                <ChevronRight :size="18" class="text-slate-300 shrink-0" />
            </button>
        </div>
    </div>
</template>
