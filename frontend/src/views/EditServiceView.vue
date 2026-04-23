<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    ArrowLeft, Check, Camera, Loader2, LocateFixed,
    Wind, Flag, Target, Activity, CircleDot, Layers3, Dumbbell, Waves, Swords,
    Sun, Moon, Lock, ChevronDown
} from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const toast  = useToastStore()

const isCreate   = route.params.id === 'new' || !route.params.id
const courtId    = isCreate ? null : parseInt(route.params.id)
const loading    = ref(isCreate ? false : true)
const saving   = ref(false)
const geoLoading = ref(false)
const uploadLoading = ref(false)
const imagePreview = ref(null)
const showPeakHours = ref(false)

const form = ref({
    name: '', location: '', type: 'shuttle', hourly_rate: '',
    description: '', image_url: '',
    lat: null, lng: null,
    open_time: '06:00', close_time: '22:00',
    morning_peak_start: '05:00', morning_peak_end: '09:00',
    evening_peak_start: '17:00', evening_peak_end: '21:00',
    peak_members_only: false,
    amenities: [],
})

const AMENITIES_LIST = ['Parking', 'Floodlights', 'Changing Room', 'Shower', 'Equipment Rental', 'Cafeteria', 'WiFi', 'First Aid']

const sportOptions = [
    { id: 'shuttle',  label: 'Badminton',  icon: Wind },
    { id: 'turf',     label: 'Football',   icon: Flag },
    { id: 'gym',      label: 'Gym',        icon: Dumbbell },
    { id: 'cricket',  label: 'Cricket',    icon: Target },
    { id: 'tennis',   label: 'Tennis',     icon: Activity },
    { id: 'swimming', label: 'Swimming',   icon: Waves },
    { id: 'boxing',   label: 'Boxing',     icon: Swords },
    { id: 'basket',   label: 'Basketball', icon: CircleDot },
    { id: 'other',    label: 'Other',      icon: Layers3 },
]

const pageTitle = computed(() => isCreate ? 'Add Venue' : 'Edit Venue')
const saveLabel = computed(() => isCreate ? 'Add Venue' : 'Save Changes')

onMounted(async () => {
    if (isCreate) return
    try {
        const res = await axios.get('/courts')
        const court = (res.data.records || []).find(c => c.id == courtId)
        if (!court) { router.replace('/my-venues'); return }
        Object.assign(form.value, {
            name:               court.name,
            location:           court.location || '',
            type:               court.type,
            hourly_rate:        court.hourly_rate,
            description:        court.description || '',
            image_url:          court.image_url || '',
            lat:                court.lat || null,
            lng:                court.lng || null,
            open_time:          court.open_time?.slice(0,5)          || '06:00',
            close_time:         court.close_time?.slice(0,5)         || '22:00',
            morning_peak_start: court.morning_peak_start?.slice(0,5) || '05:00',
            morning_peak_end:   court.morning_peak_end?.slice(0,5)   || '09:00',
            evening_peak_start: court.evening_peak_start?.slice(0,5) || '17:00',
            evening_peak_end:   court.evening_peak_end?.slice(0,5)   || '21:00',
            peak_members_only:  !!court.peak_members_only,
            amenities:          Array.isArray(court.amenities) ? [...court.amenities] : [],
        })
    } catch { toast.error('Could not load court') }
    finally { loading.value = false }
})

const toggleAmenity = (tag) => {
    const idx = form.value.amenities.indexOf(tag)
    if (idx >= 0) form.value.amenities.splice(idx, 1)
    else form.value.amenities.push(tag)
}

const handleImageSelect = async (event) => {
    const file = event.target.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (e) => { imagePreview.value = e.target.result }
    reader.readAsDataURL(file)
    uploadLoading.value = true
    try {
        const fd = new FormData()
        fd.append('image', file)
        const res = await axios.post('/upload', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
        form.value.image_url = res.data.url
        toast.success('Photo uploaded!')
    } catch { toast.error('Upload failed'); imagePreview.value = null }
    finally { uploadLoading.value = false; event.target.value = '' }
}

const detectLocation = () => {
    if (!navigator.geolocation) { toast.error('Geolocation not supported'); return }
    geoLoading.value = true
    navigator.geolocation.getCurrentPosition(
        async (pos) => {
            form.value.lat = pos.coords.latitude
            form.value.lng = pos.coords.longitude
            try {
                const r = await fetch(
                    `https://nominatim.openstreetmap.org/reverse?lat=${form.value.lat}&lon=${form.value.lng}&format=json`,
                    { headers: { 'Accept-Language': 'en' } }
                )
                const d = await r.json()
                const suburb = d.address?.suburb || d.address?.neighbourhood || ''
                const city   = d.address?.city   || d.address?.town || d.address?.village || ''
                form.value.location = [suburb, city].filter(Boolean).join(', ')
            } catch {}
            geoLoading.value = false
            toast.success('Location pinned!')
        },
        () => { geoLoading.value = false; toast.error('Location permission denied') },
        { timeout: 8000 }
    )
}

const save = async () => {
    if (!form.value.name.trim() || !form.value.hourly_rate) {
        toast.error('Name and rate are required'); return
    }
    saving.value = true
    try {
        if (isCreate) {
            await axios.post('/courts', { ...form.value, owner_id: auth.user?.id })
            toast.success('Venue added!')
        } else {
            await axios.put(`/courts/${courtId}`, { ...form.value, owner_id: auth.user?.id })
            toast.success('Service updated!')
        }
        router.replace('/my-venues')
    } catch { toast.error(isCreate ? 'Failed to add venue' : 'Update failed') }
    finally { saving.value = false }
}
</script>

<template>
    <div class="min-h-full bg-slate-50">

        <!-- Sticky top bar -->
        <div class="sticky top-0 z-30 bg-white border-b border-slate-100 px-4 py-3.5 flex items-center gap-3"
            style="box-shadow: 0 1px 6px rgba(0,0,0,0.06)">
            <button @click="router.back()"
                class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center active:scale-90 transition-transform shrink-0">
                <ArrowLeft :size="20" class="text-slate-600" />
            </button>
            <h1 class="flex-1 font-extrabold text-slate-900 text-base truncate">{{ pageTitle }}</h1>
            <button @click="save" :disabled="saving || uploadLoading"
                class="flex items-center gap-1.5 bg-primary text-white font-bold text-sm px-4 py-2 rounded-xl disabled:opacity-50 active:scale-95 transition-all">
                <Loader2 v-if="saving" :size="14" class="animate-spin" />
                <Check v-else :size="14" />
                Save
            </button>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="flex items-center justify-center py-24">
            <Loader2 :size="32" class="animate-spin text-primary" />
        </div>

        <div v-else class="px-4 py-5 space-y-4 pb-8">

            <!-- ── Photo ── -->
            <div class="bg-white rounded-2xl overflow-hidden ring-1 ring-slate-100 shadow-sm">
                <div class="px-4 pt-4 pb-2">
                    <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Photo</p>
                </div>
                <div class="relative h-48 bg-slate-100 cursor-pointer">
                    <img v-if="imagePreview || form.image_url"
                        :src="imagePreview || form.image_url"
                        class="w-full h-full object-cover" />
                    <div v-else class="absolute inset-0 flex flex-col items-center justify-center gap-2 text-slate-300">
                        <Camera :size="36" />
                        <p class="text-sm font-medium text-slate-400">Tap to add a photo</p>
                    </div>
                    <label class="absolute inset-0 cursor-pointer">
                        <input type="file" accept="image/jpeg,image/png,image/webp"
                            class="hidden" @change="handleImageSelect" />
                    </label>
                    <div v-if="uploadLoading" class="absolute inset-0 bg-white/80 flex items-center justify-center">
                        <Loader2 :size="28" class="animate-spin text-primary" />
                    </div>
                    <!-- Edit overlay -->
                    <div v-if="!uploadLoading && (imagePreview || form.image_url)"
                        class="absolute bottom-3 right-3">
                        <label class="flex items-center gap-1.5 bg-black/60 text-white text-xs font-bold px-3 py-1.5 rounded-full cursor-pointer">
                            <Camera :size="12" /> Change
                            <input type="file" accept="image/jpeg,image/png,image/webp"
                                class="hidden" @change="handleImageSelect" />
                        </label>
                    </div>
                </div>
            </div>

            <!-- ── Basic Info ── -->
            <div class="bg-white rounded-2xl ring-1 ring-slate-100 shadow-sm divide-y divide-slate-50">
                <div class="px-4 py-3">
                    <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2.5">Basic Info</p>
                    <label class="block text-xs font-semibold text-slate-500 mb-1">Venue Name *</label>
                    <input v-model="form.name" type="text" placeholder="e.g. GS Sports Arena"
                        class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-slate-50" />
                </div>
                <div class="px-4 py-3">
                    <label class="block text-xs font-semibold text-slate-500 mb-1">Description</label>
                    <textarea v-model="form.description" rows="3" placeholder="Describe your venue, facilities, etc."
                        class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-primary/30 bg-slate-50">
                    </textarea>
                </div>
                <div class="px-4 py-3">
                    <label class="block text-xs font-semibold text-slate-500 mb-1">Base Rate per Hour (₹) *</label>
                    <p class="text-[11px] text-slate-400 mt-1.5">You can set per-court rates from the Services section</p>
                    <input v-model="form.hourly_rate" type="number" placeholder="500"
                        class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-slate-50" />
                </div>
            </div>

            <!-- ── Sport Type ── -->
            <div class="bg-white rounded-2xl px-4 py-4 ring-1 ring-slate-100 shadow-sm">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Primary Sport</p>
                <div class="grid grid-cols-3 gap-2">
                    <button v-for="sport in sportOptions" :key="sport.id"
                        @click="form.type = sport.id"
                        class="flex flex-col items-center gap-1.5 py-3 rounded-xl border-2 transition-all text-xs font-semibold"
                        :class="form.type === sport.id
                            ? 'border-primary bg-primary-light text-primary'
                            : 'border-slate-100 bg-slate-50 text-slate-500'">
                        <component :is="sport.icon" :size="20" />
                        {{ sport.label }}
                    </button>
                </div>
            </div>

            <!-- ── Location ── -->
            <div class="bg-white rounded-2xl px-4 py-4 ring-1 ring-slate-100 shadow-sm">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Location</p>
                <div class="flex gap-2">
                    <input v-model="form.location" type="text" placeholder="City or area name"
                        class="flex-1 rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-slate-50" />
                    <button @click="detectLocation" :disabled="geoLoading"
                        class="w-12 h-12 rounded-xl bg-primary-light flex items-center justify-center shrink-0 active:scale-95 transition-transform disabled:opacity-50">
                        <Loader2 v-if="geoLoading" :size="18" class="animate-spin text-primary" />
                        <LocateFixed v-else :size="18" class="text-primary" />
                    </button>
                </div>
                <p v-if="form.lat && form.lng" class="text-[11px] text-emerald-600 font-semibold mt-2">
                    📍 GPS: {{ Number(form.lat).toFixed(4) }}, {{ Number(form.lng).toFixed(4) }}
                </p>
            </div>

            <!-- ── Operating Hours ── -->
            <div class="bg-white rounded-2xl px-4 py-4 ring-1 ring-slate-100 shadow-sm">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Operating Hours</p>
                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="text-[11px] font-semibold text-slate-400 block mb-1.5">Opens</label>
                        <input v-model="form.open_time" type="time"
                            class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-slate-50" />
                    </div>
                    <div>
                        <label class="text-[11px] font-semibold text-slate-400 block mb-1.5">Closes</label>
                        <input v-model="form.close_time" type="time"
                            class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-slate-50" />
                    </div>
                </div>
            </div>

            <!-- ── Peak Hours ── -->
            <div class="bg-white rounded-2xl ring-1 ring-slate-100 shadow-sm overflow-hidden">
                <button @click="showPeakHours = !showPeakHours"
                    class="w-full flex items-center justify-between px-4 py-4">
                    <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Peak Hours</p>
                    <ChevronDown :size="16" class="text-slate-400 transition-transform"
                        :class="showPeakHours ? 'rotate-180' : ''" />
                </button>

                <div v-if="showPeakHours" class="px-4 pb-4 space-y-3">
                <div class="flex items-center justify-between mb-1">
                    <p class="text-xs text-slate-500">Restrict peak slots to members only</p>
                    <label class="relative flex items-center cursor-pointer">
                        <input type="checkbox" v-model="form.peak_members_only" class="sr-only peer" />
                        <div class="w-10 h-5 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors"></div>
                        <div class="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform peer-checked:translate-x-5"></div>
                    </label>
                </div>

                <div class="space-y-3">
                    <!-- Morning peak -->
                    <div class="bg-amber-50 rounded-xl p-3">
                        <div class="flex items-center gap-1.5 mb-2.5">
                            <Sun :size="13" class="text-amber-500" />
                            <span class="text-xs font-bold text-amber-700">Morning Peak</span>
                        </div>
                        <div class="grid grid-cols-2 gap-2">
                            <div>
                                <label class="text-[10px] font-semibold text-amber-600 block mb-1">From</label>
                                <input v-model="form.morning_peak_start" type="time"
                                    class="w-full rounded-lg border border-amber-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-amber-300" />
                            </div>
                            <div>
                                <label class="text-[10px] font-semibold text-amber-600 block mb-1">To</label>
                                <input v-model="form.morning_peak_end" type="time"
                                    class="w-full rounded-lg border border-amber-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-amber-300" />
                            </div>
                        </div>
                    </div>

                    <!-- Evening peak -->
                    <div class="bg-indigo-50 rounded-xl p-3">
                        <div class="flex items-center gap-1.5 mb-2.5">
                            <Moon :size="13" class="text-indigo-500" />
                            <span class="text-xs font-bold text-indigo-700">Evening Peak</span>
                        </div>
                        <div class="grid grid-cols-2 gap-2">
                            <div>
                                <label class="text-[10px] font-semibold text-indigo-600 block mb-1">From</label>
                                <input v-model="form.evening_peak_start" type="time"
                                    class="w-full rounded-lg border border-indigo-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-300" />
                            </div>
                            <div>
                                <label class="text-[10px] font-semibold text-indigo-600 block mb-1">To</label>
                                <input v-model="form.evening_peak_end" type="time"
                                    class="w-full rounded-lg border border-indigo-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-300" />
                            </div>
                        </div>
                    </div>
                </div>

                <div v-if="form.peak_members_only" class="mt-3 flex items-center gap-2 bg-amber-50 border border-amber-100 rounded-xl px-3 py-2.5">
                    <Lock :size="13" class="text-amber-600 shrink-0" />
                    <p class="text-[11px] text-amber-700 font-medium">Walk-in bookings will be blocked during these windows</p>
                </div>
                </div>
            </div>

            <!-- ── Amenities ── -->
            <div class="bg-white rounded-2xl px-4 py-4 ring-1 ring-slate-100 shadow-sm">
                <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Amenities</p>
                <div class="flex flex-wrap gap-2">
                    <button v-for="tag in AMENITIES_LIST" :key="tag"
                        type="button"
                        @click="toggleAmenity(tag)"
                        class="px-3.5 py-2 rounded-full text-xs font-semibold border-2 transition-all"
                        :class="form.amenities.includes(tag)
                            ? 'bg-primary border-primary text-white'
                            : 'bg-slate-50 border-slate-200 text-slate-500'">
                        {{ tag }}
                    </button>
                </div>
            </div>

            <!-- ── Save button ── -->
            <button @click="save" :disabled="saving || uploadLoading"
                class="w-full bg-primary text-white font-extrabold py-4 rounded-2xl flex items-center justify-center gap-2 shadow-md active:scale-[0.98] transition-all disabled:opacity-50">
                <Loader2 v-if="saving" :size="18" class="animate-spin" />
                <Check v-else :size="18" />
                {{ saveLabel }}
            </button>

        </div>
    </div>
</template>
