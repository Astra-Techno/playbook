<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import axios from 'axios'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import {
    Search, MapPin, SlidersHorizontal, Heart, ChevronRight,
    Wind, CircleDot, Target, Flag, Activity, Layers3,
    Dumbbell, Waves, Swords, Loader2, Star, Flame, Map,
    Lock, Bell, X, RotateCcw, KeyRound, Clock
} from 'lucide-vue-next'
import ClaimVenueSheet from '../components/ClaimVenueSheet.vue'

const router = useRouter()
const auth   = useAuthStore()

const courts        = ref([])
const loading       = ref(false)
const searchText    = ref('')
const selectedSport = ref('All')
const selectedRadius = ref(25)
const locating      = ref(false)
const userLat       = ref(null)
const userLng       = ref(null)
const favorites     = ref(new Set())
const favLoading    = ref(new Set())

const RADIUS_OPTIONS = [5, 10, 25, 50]
const filterSheet = ref(false)

// draft state inside the sheet (applied on "Apply")
const draftSport  = ref('All')
const draftRadius = ref(25)

const openFilters = () => {
    draftSport.value  = selectedSport.value
    draftRadius.value = selectedRadius.value
    filterSheet.value = true
}

const applyFilters = () => {
    selectedSport.value  = draftSport.value
    selectedRadius.value = draftRadius.value
    filterSheet.value    = false
}

const resetFilters = () => {
    draftSport.value  = 'All'
    draftRadius.value = 25
}

// Claim sheet
const claimSheet = ref({ show: false, place: null })
const openClaim  = (place) => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    claimSheet.value = { show: true, place }
}

const activeFilterCount = computed(() => {
    let n = 0
    if (selectedSport.value  !== 'All') n++
    if (selectedRadius.value !== 25)    n++
    return n
})

// ── GPS localStorage cache (30 min) ───────────────────────────
const GPS_CACHE_KEY = 'kocourt_gps_cache'
const GPS_TTL = 6 * 60 * 60 * 1000 // 6 hours

function saveGpsCache(lat, lng) {
    localStorage.setItem(GPS_CACHE_KEY, JSON.stringify({ lat, lng, ts: Date.now() }))
}
function loadGpsCache() {
    try {
        const raw = localStorage.getItem(GPS_CACHE_KEY)
        if (!raw) return null
        const { lat, lng, ts } = JSON.parse(raw)
        if (Date.now() - ts < GPS_TTL) return { lat, lng }
        localStorage.removeItem(GPS_CACHE_KEY)
    } catch { localStorage.removeItem(GPS_CACHE_KEY) }
    return null
}

// Ghost listings
const ghostPlaces     = ref([])
const ghostLoading    = ref(false)
const requestingId    = ref(null)   // place id currently being requested
const fetched         = ref(false)  // true after first fetchVenues completes

// Location picker sheet
const locPicker      = ref(false)
const locInput       = ref('')
const locSuggestions = ref([])
const locLoading     = ref(false)
let   locTimer       = null

const openLocPicker = () => {
    locInput.value = searchText.value
    locSuggestions.value = []
    locPicker.value = true
}

const applyLocInput = (label, lat, lng) => {
    const v = (label || locInput.value).trim()
    if (!v) return
    userLat.value = lat ?? null
    userLng.value = lng ?? null
    if (lat && lng) saveGpsCache(lat, lng)
    searchText.value = v
    locSuggestions.value = []
    locPicker.value = false
    fetchVenues()
    if (lat && lng) fetchGhostPlaces(lat, lng)
}

const onLocInputChange = () => {
    clearTimeout(locTimer)
    locSuggestions.value = []
    const q = locInput.value.trim()
    if (q.length < 2) return
    locLoading.value = true
    locTimer = setTimeout(async () => {
        try {
            const res  = await fetch(
                `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&format=json&addressdetails=1&limit=6&featuretype=city`,
                { headers: { 'Accept-Language': 'en' } }
            )
            const data = await res.json()
            locSuggestions.value = data
                .filter(r => ['city','town','village','suburb','county','state_district','municipality'].includes(r.type) || r.class === 'place' || r.class === 'boundary')
                .slice(0, 5)
                .map(r => {
                    const a = r.address || {}
                    const city = a.city || a.town || a.village || a.suburb || a.county || r.name
                    const state = a.state || ''
                    const country = a.country || ''
                    const label = [city, state, country].filter(Boolean).join(', ')
                    return { label, lat: parseFloat(r.lat), lng: parseFloat(r.lon) }
                })
        } catch { locSuggestions.value = [] }
        finally { locLoading.value = false }
    }, 350)
}

const useGpsFromPicker = () => { locSuggestions.value = []; locPicker.value = false; detectLocation() }

// ── Location detection ────────────────────────────────────────
const applyGps = async (latitude, longitude) => {
    userLat.value = latitude; userLng.value = longitude
    saveGpsCache(latitude, longitude)
    try {
        const res  = await fetch(
            `https://nominatim.openstreetmap.org/reverse?lat=${latitude}&lon=${longitude}&format=json`,
            { headers: { 'Accept-Language': 'en' } }
        )
        const data = await res.json()
        const city = data.address?.city || data.address?.town
            || data.address?.village || data.address?.suburb || data.address?.county
        if (city) searchText.value = city
    } catch { /* ignore */ }
    fetchVenues()
    fetchGhostPlaces(latitude, longitude)
}

const detectLocation = () => {
    if (!navigator.geolocation) { fetchVenues(); return }
    locating.value = true
    navigator.geolocation.getCurrentPosition(
        async (pos) => {
            try {
                await applyGps(pos.coords.latitude, pos.coords.longitude)
            } catch { /* ignore */ }
            finally { locating.value = false }
        },
        () => { locating.value = false; fetchVenues() },  // denied/timeout → still load all venues
        { timeout: 8000 }
    )
}

// ── Ghost listings ────────────────────────────────────────────
const fetchGhostPlaces = async (lat, lng) => {
    ghostLoading.value = true
    try {
        const uid = auth.user?.id ? `&user_id=${auth.user.id}` : ''
        const res = await axios.get(`/nearby-places?lat=${lat}&lng=${lng}${uid}`)
        ghostPlaces.value = res.data.places || []
    } catch { ghostPlaces.value = [] }
    finally { ghostLoading.value = false }
}

const requestService = async (place) => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    if (requestingId.value === place.id) return
    requestingId.value = place.id
    try {
        const res = await axios.post('/service-requests', {
            place_id: place.id,
            user_id:  auth.user.id,
        })
        place.user_requested  = true
        place.request_count   = res.data.request_count
    } catch { /* ignore */ }
    finally { requestingId.value = null }
}

const onSearchInput = () => { userLat.value = null; userLng.value = null }

// ── Categories ────────────────────────────────────────────────
const categories = [
    { id: 'All',      label: 'All',        icon: Layers3,   emoji: '🏟️' },
    { id: 'turf',     label: 'Football',   icon: Flag,      emoji: '⚽' },
    { id: 'shuttle',  label: 'Badminton',  icon: Wind,      emoji: '🏸' },
    { id: 'tennis',   label: 'Tennis',     icon: Activity,  emoji: '🎾' },
    { id: 'cricket',  label: 'Cricket',    icon: Target,    emoji: '🏏' },
    { id: 'gym',      label: 'Gym',        icon: Dumbbell,  emoji: '🏋️' },
    { id: 'swimming', label: 'Swimming',   icon: Waves,     emoji: '🏊' },
    { id: 'boxing',   label: 'Boxing',     icon: Swords,    emoji: '🥊' },
    { id: 'basket',   label: 'Basketball', icon: CircleDot, emoji: '🏀' },
]

// ── Venue images ──────────────────────────────────────────────
const venueImages = {
    shuttle:  'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&q=80',
    turf:     'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=600&q=80',
    gym:      'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
    cricket:  'https://images.unsplash.com/photo-1540747913346-19212a4b8277?w=600&q=80',
    tennis:   'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&q=80',
    basket:   'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&q=80',
    swimming: 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=600&q=80',
    boxing:   'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=600&q=80',
    other:    'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80',
}
const getImage = (v) => v.image_url || venueImages[v.type] || venueImages.other

// ── Computed ──────────────────────────────────────────────────
const hasLocation = computed(() => !!searchText.value.trim() || (!!userLat.value && !!userLng.value))

const locationLabel = computed(() => {
    if (locating.value) return 'Detecting...'
    if (searchText.value) return (userLat.value ? 'Near ' : '') + searchText.value
    if (userLat.value && userLng.value) return 'Near You'
    return 'All Venues'
})
const sectionTitle = computed(() => {
    if (selectedSport.value === 'All') return 'Top Venues Near You'
    return (categories.find(c => c.id === selectedSport.value)?.label || '') + ' Venues'
})

const toggleFavorite = async (e, id) => {
    e.stopPropagation()
    if (!auth.isLoggedIn) { router.push('/login'); return }
    if (favLoading.value.has(id)) return
    const fl = new Set(favLoading.value); fl.add(id); favLoading.value = fl
    try {
        const res = await axios.post('/favorites', { user_id: auth.user?.id, court_id: id })
        const s = new Set(favorites.value)
        res.data.favorited ? s.add(id) : s.delete(id)
        favorites.value = s
    } catch { /* ignore */ }
    finally {
        const fl2 = new Set(favLoading.value); fl2.delete(id); favLoading.value = fl2
    }
}

// ── Data fetch ────────────────────────────────────────────────
const fetchVenues = async () => {
    loading.value = true
    try {
        const p = new URLSearchParams()
        if (userLat.value && userLng.value) {
            p.set('lat', userLat.value); p.set('lng', userLng.value)
            p.set('radius', selectedRadius.value)
        } else if (searchText.value) {
            p.set('location', searchText.value)
        }
        if (selectedSport.value !== 'All') p.set('type', selectedSport.value)
        const res = await axios.get('/courts' + (p.toString() ? '?' + p : ''))
        courts.value = res.data.records || []
    } catch { courts.value = [] }
    finally { loading.value = false; fetched.value = true }
}

onMounted(async () => {
    // Try GPS cache first
    const cached = loadGpsCache()
    if (cached) {
        userLat.value = cached.lat; userLng.value = cached.lng
        fetchVenues()
        fetchGhostPlaces(cached.lat, cached.lng)
    } else {
        detectLocation()
    }
    if (auth.isLoggedIn) {
        try {
            const res = await axios.get(`/favorites?user_id=${auth.user?.id}`)
            favorites.value = new Set(res.data.ids || [])
        } catch { /* ignore */ }
    }
})

let timer = null
watch(searchText, () => {
    clearTimeout(timer)
    if (searchText.value.trim()) { timer = setTimeout(fetchVenues, 400) } else if (userLat.value && userLng.value) { fetchVenues() } else { courts.value = [] }
})
watch(selectedSport, () => {
    if (fetched.value) {
        fetchVenues()
        if (userLat.value && userLng.value) fetchGhostPlaces(userLat.value, userLng.value)
    }
})
watch(selectedRadius, () => { if (userLat.value && userLng.value) fetchVenues() })
</script>

<template>
    <div class="min-h-full bg-white">

        <!-- Location label — teleports into header slot -->
        <Teleport to="#header-subtitle">
            <button @click="openLocPicker"
                class="flex items-center gap-1 active:opacity-60 transition-opacity">
                <MapPin :size="13" class="text-primary shrink-0" style="fill:currentColor" />
                <span class="text-[13px] font-bold tracking-tight text-on-surface truncate max-w-[160px]">{{ locationLabel }}</span>
                <ChevronRight :size="15" class="text-on-surface-variant/60" />
            </button>
        </Teleport>

        <!-- ── Search bar (inside scroll — Zomato pattern) ── -->
        <div class="px-5 mt-2">
            <div class="flex gap-2">
                <!-- Search input -->
                <div class="relative flex-1">
                    <div class="absolute left-3.5 top-1/2 -translate-y-1/2 z-10">
                        <Search :size="18" class="text-primary" />
                    </div>
                    <input v-model="searchText" @input="onSearchInput"
                        type="search"
                        placeholder="Search for Badminton, Gyms..."
                        class="w-full h-12 pl-10 pr-10 bg-surface-container-lowest border border-surface-variant/50
                               rounded-xl text-sm focus:ring-4 focus:ring-primary/5 focus:border-primary
                               transition-all shadow-soft placeholder:text-on-surface-variant/40 font-medium outline-none" />
                    <button @click="detectLocation" :disabled="locating"
                        class="absolute right-3 top-1/2 -translate-y-1/2 disabled:opacity-50">
                        <Loader2 v-if="locating" :size="18" class="animate-spin text-on-surface-variant/60" />
                        <MapPin v-else :size="18" class="text-on-surface-variant/60"
                            :class="userLat && userLng ? '!text-primary' : ''" />
                    </button>
                </div>
                <!-- Filter button -->
                <button @click="openFilters"
                    class="h-12 w-12 flex items-center justify-center bg-surface-container-lowest border border-surface-variant/50 rounded-xl shadow-soft active:bg-surface-container transition-colors relative shrink-0">
                    <SlidersHorizontal :size="18" class="text-on-surface" />
                    <span v-if="activeFilterCount > 0"
                        class="absolute top-1.5 right-1.5 w-3.5 h-3.5 bg-primary text-white text-[8px] font-black rounded-full flex items-center justify-center">
                        {{ activeFilterCount }}
                    </span>
                </button>
            </div>
        </div>

        <!-- ── Square sport category chips ── -->
        <div class="mt-3">
            <div class="flex overflow-x-auto scrollbar-hide gap-3 px-5 pb-1">
                <button v-for="c in categories" :key="c.id"
                    @click="selectedSport = c.id"
                    class="flex flex-col items-center gap-2 min-w-[72px] shrink-0 active:scale-95 duration-200">
                    <!-- Square icon box -->
                    <div class="w-16 h-16 rounded-2xl flex items-center justify-center transition-all"
                        :class="selectedSport === c.id
                            ? 'bg-primary text-on-primary shadow-lg shadow-primary/25 border-b-2 border-primary-container -translate-y-0.5'
                            : 'bg-surface-container-lowest text-on-surface-variant/80 shadow-soft border border-surface-variant/40'">
                        <component :is="c.icon" :size="28" :stroke-width="selectedSport === c.id ? 2 : 1.5" />
                    </div>
                    <span class="text-[12px] font-bold tracking-tight"
                        :class="selectedSport === c.id ? 'text-primary' : 'text-on-surface-variant'">
                        {{ c.label }}
                    </span>
                </button>
            </div>
        </div>

        <!-- ── Main content ── -->
        <div class="px-5 pt-5 pb-4">

            <!-- No location yet -->
            <div v-if="!fetched && !hasLocation && !locating" class="flex flex-col items-center py-20 text-center px-6">
                <div class="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mb-5">
                    <MapPin :size="36" class="text-gray-400" :stroke-width="1.5" />
                </div>
                <p class="font-extrabold text-black text-[20px] mb-2">Where are you playing?</p>
                <p class="text-[14px] text-gray-400 max-w-[240px] leading-relaxed">
                    Search for a city or allow location access to discover venues near you.
                </p>
                <button @click="detectLocation"
                    class="mt-6 flex items-center gap-2 bg-black text-white text-[14px] font-bold px-7 py-3.5 rounded-full active:scale-95 transition-transform">
                    <MapPin :size="16" />
                    Use My Location
                </button>
            </div>

            <template v-else-if="fetched || hasLocation || locating">

            <!-- Skeleton -->
            <div v-if="loading" class="space-y-4">
                <div v-for="i in 3" :key="i"
                    class="bg-white rounded-2xl overflow-hidden shadow-card animate-pulse">
                    <div class="h-44 bg-slate-200"></div>
                    <div class="p-4 space-y-2.5">
                        <div class="flex justify-between">
                            <div class="h-4 bg-slate-200 rounded-lg w-2/5"></div>
                            <div class="h-4 bg-slate-200 rounded w-10"></div>
                        </div>
                        <div class="h-3 bg-slate-200 rounded-lg w-3/5"></div>
                        <div class="flex justify-between items-center pt-1">
                            <div class="h-5 bg-slate-200 rounded-lg w-24"></div>
                            <div class="h-9 bg-slate-200 rounded-xl w-28"></div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Empty state -->
            <div v-else-if="courts.length === 0" class="flex flex-col items-center py-20 text-center">
                <div class="w-16 h-16 bg-gray-100 text-black rounded-full flex items-center justify-center mb-4">
                    <Map :size="32" :stroke-width="2.5" />
                </div>
                <p class="font-extrabold text-gray-700 text-base">No venues found</p>
                <p class="text-sm text-gray-400 mt-1.5 max-w-[220px]">
                    Try searching a different city or selecting another category
                </p>
            </div>

            <!-- Section header -->
            <div class="flex justify-between items-end mb-3">
                <div>
                    <h2 class="font-black tracking-tight text-[22px] text-on-surface">Venues near you</h2>
                    <p class="text-on-surface-variant text-[13px] font-medium mt-0.5">Handpicked for your game today</p>
                </div>
                <button @click="router.push('/find-courts')"
                    class="text-primary font-bold text-[13px] flex items-center gap-0.5 bg-primary/5 px-3 py-1.5 rounded-full border border-primary/10 active:bg-primary/10 transition-colors">
                    See all <ChevronRight :size="14" />
                </button>
            </div>

            <!-- Venue cards — Kinetic Stadium design -->
            <div class="space-y-4">
                <div v-for="(venue, idx) in courts" :key="venue.id"
                    @click="router.push('/courts/' + venue.id)"
                    class="rounded-2xl overflow-hidden bg-surface-container-lowest cursor-pointer
                           shadow-md shadow-black/5 border border-surface-variant/30
                           transition-all active:scale-[0.98]">

                    <!-- Image h-52 with gradient overlay -->
                    <div class="relative h-52 w-full overflow-hidden">
                        <img :src="getImage(venue)" :alt="venue.name"
                            class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
                            loading="lazy"
                            onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80'" />
                        <!-- Bottom gradient -->
                        <div class="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent"></div>

                        <!-- Top-left: Bestseller badge (first card) or Trending (rest) -->
                        <div class="absolute top-3 left-3 z-10">
                            <span v-if="idx === 0"
                                class="bg-primary text-white px-2.5 py-1 rounded-lg text-[10px] font-black tracking-widest uppercase shadow-lg border border-white/20">
                                Bestseller
                            </span>
                            <span v-else-if="venue.is_featured"
                                class="bg-secondary text-on-secondary px-2.5 py-1 rounded-lg text-[10px] font-black tracking-widest uppercase shadow-lg border border-white/10">
                                Featured
                            </span>
                        </div>

                        <!-- Bottom-right: price badge on image -->
                        <div class="absolute bottom-3 right-3 z-10">
                            <div class="bg-white/90 backdrop-blur-md px-3 py-1.5 rounded-xl text-on-surface font-black text-sm shadow-sm">
                                ₹{{ venue.hourly_rate }}<span class="text-[10px] text-on-surface-variant font-medium ml-0.5">/slot</span>
                            </div>
                        </div>
                    </div>

                    <!-- Card body -->
                    <div class="p-4">
                        <div class="flex justify-between items-start">
                            <div class="flex-1 min-w-0">
                                <h3 class="text-[17px] font-bold text-on-surface leading-tight hover:text-primary transition-colors">{{ venue.name }}</h3>
                                <div class="flex items-center gap-3 mt-1.5 text-on-surface-variant text-[12px] font-medium">
                                    <div class="flex items-center gap-1">
                                        <MapPin :size="13" class="text-primary shrink-0" style="fill:currentColor" />
                                        {{ venue.distance_km != null ? venue.distance_km + ' km' : (venue.location || 'Nearby') }}
                                    </div>
                                    <div class="flex items-center gap-1">
                                        <Clock :size="13" class="text-primary shrink-0" />
                                        {{ venue.availability || 'Open today' }}
                                    </div>
                                </div>
                            </div>
                            <!-- Rating badge -->
                            <div v-if="venue.avg_rating"
                                class="flex items-center gap-1 bg-surface-container px-2 py-1 rounded-lg text-on-surface font-bold text-[13px] border border-surface-variant/40 shrink-0 ml-3">
                                {{ parseFloat(venue.avg_rating).toFixed(1) }}
                                <Star :size="11" class="text-primary" style="fill:currentColor" />
                            </div>
                        </div>

                        <!-- Footer: social proof + reviews -->
                        <div class="mt-3.5 pt-3 border-t border-surface-variant/30 flex justify-between items-center">
                            <div class="flex items-center gap-2">
                                <!-- Animated ping dot -->
                                <div class="flex h-2 w-2 relative shrink-0">
                                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                                    <span class="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
                                </div>
                                <span class="text-[11px] font-bold text-primary tracking-tight">
                                    {{ venue.booking_count ? venue.booking_count + ' booked today' : 'Available now' }}
                                </span>
                            </div>
                            <span v-if="venue.review_count" class="text-[11px] font-semibold text-on-surface-variant/70">
                                {{ venue.review_count }}+ reviews
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ── Ghost Listings Section ── -->
            <div v-if="ghostLoading || ghostPlaces.length > 0" class="mt-8">
                <!-- Section header -->
                <div class="flex items-center justify-between mb-3">
                    <div>
                        <h2 class="text-[17px] font-extrabold text-black">Also Nearby</h2>
                        <p class="text-[11px] text-gray-400 font-medium mt-0.5">Not on KoCourt yet — show your interest</p>
                    </div>
                    <span class="text-[10px] font-black bg-amber-100 text-amber-700 px-2.5 py-1 rounded-full uppercase tracking-wide">
                        Coming Soon
                    </span>
                </div>

                <!-- Ghost skeletons -->
                <div v-if="ghostLoading && ghostPlaces.length === 0" class="space-y-4">
                    <div v-for="i in 3" :key="i" class="bg-white rounded-2xl overflow-hidden shadow-card animate-pulse opacity-60">
                        <div class="h-44 bg-slate-200"></div>
                        <div class="p-4 space-y-2.5">
                            <div class="h-4 bg-slate-200 rounded-lg w-2/5"></div>
                            <div class="h-3 bg-slate-200 rounded-lg w-3/5"></div>
                            <div class="h-9 bg-slate-200 rounded-xl w-full mt-2"></div>
                        </div>
                    </div>
                </div>

                <!-- Ghost cards -->
                <div v-else class="space-y-6">
                    <div v-for="place in ghostPlaces" :key="place.id"
                        class="cursor-pointer group">

                        <!-- Image with desaturated overlay -->
                        <div class="relative w-full aspect-[4/3] rounded-3xl overflow-hidden mb-4 bg-gray-100">
                            <img :src="place.image_url" :alt="place.name"
                                class="w-full h-full object-cover grayscale-[40%] brightness-90 group-hover:scale-[1.03] transition-transform duration-500"
                                loading="lazy"
                                onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80'" />

                            <!-- NOT ON KOCOURT badge -->
                            <div class="absolute top-4 left-4 z-10">
                                <span class="bg-black/70 backdrop-blur text-white text-[9px] font-extrabold px-3.5 py-1.5 rounded-full tracking-widest uppercase flex items-center gap-1.5">
                                    <Lock :size="9" :stroke-width="3" />
                                    Not on KoCourt yet
                                </span>
                            </div>

                            <!-- Rating badge -->
                            <div v-if="place.rating" class="absolute top-4 right-4 z-10">
                                <span class="bg-white/90 backdrop-blur text-amber-700 text-[10px] font-extrabold px-2.5 py-1 rounded-full flex items-center gap-1">
                                    <Star :size="10" class="fill-amber-400 text-amber-400" />
                                    {{ place.rating }}
                                </span>
                            </div>

                            <!-- Type badge -->
                            <div class="absolute bottom-4 left-4 z-10">
                                <span class="bg-white/90 backdrop-blur text-black text-[10px] font-extrabold px-3.5 py-1.5 rounded-full tracking-wide uppercase flex items-center gap-1.5 shadow-sm">
                                    <component :is="categories.find(c => c.id === place.type)?.icon" :size="11" :stroke-width="3" />
                                    {{ categories.find(c => c.id === place.type)?.label || place.type }}
                                </span>
                            </div>
                        </div>

                        <!-- Card body -->
                        <div>
                            <h3 class="font-extrabold text-black text-[18px] leading-tight mb-1">{{ place.name }}</h3>
                            <div class="flex items-center gap-1 text-gray-500 text-[14px] mb-3">
                                <span class="truncate">{{ place.address }}</span>
                            </div>

                            <!-- Interest count -->
                            <div v-if="place.request_count > 0" class="flex items-center gap-1.5 mb-3.5">
                                <div class="flex -space-x-1.5">
                                    <div v-for="n in Math.min(place.request_count, 3)" :key="n"
                                        class="w-5 h-5 rounded-full bg-gray-200 border-2 border-white flex items-center justify-center">
                                        <span class="text-[7px] font-extrabold text-black">{{ n }}</span>
                                    </div>
                                </div>
                                <span class="text-[12px] font-semibold text-gray-500">
                                    {{ place.request_count }} {{ place.request_count === 1 ? 'person' : 'people' }} interested
                                </span>
                            </div>

                            <!-- CTAs -->
                            <div class="flex gap-2">
                                <!-- Claim this Venue (primary) -->
                                <button @click="openClaim(place)"
                                    class="flex-1 flex items-center justify-center gap-2 bg-black text-white text-[13px] font-bold px-4 py-3 rounded-full active:scale-95 transition-all shadow-sm">
                                    <KeyRound :size="13" :stroke-width="2.5" />
                                    Claim Venue
                                </button>
                                <!-- Request / Requested (secondary) -->
                                <button v-if="!place.user_requested"
                                    @click="requestService(place)"
                                    :disabled="requestingId === place.id"
                                    class="flex items-center gap-1.5 bg-gray-100 text-gray-700 text-[13px] font-bold px-5 py-3 rounded-full active:scale-95 disabled:opacity-60 transition-all shrink-0">
                                    <Loader2 v-if="requestingId === place.id" :size="12" class="animate-spin" />
                                    <Bell v-else :size="12" :stroke-width="2.5" />
                                    Notify Me
                                </button>
                                <div v-else
                                    class="flex items-center gap-1.5 bg-gray-100 text-black text-[13px] font-bold px-5 py-3 rounded-full shrink-0">
                                    <svg viewBox="0 0 12 12" fill="none" class="w-3 h-3 text-black">
                                        <path d="M2 6l3 3 5-5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                                    </svg>
                                    Notified
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            </template>
        </div>
    </div>

    <!-- ── Claim Venue Sheet ── -->
    <ClaimVenueSheet
        v-model="claimSheet.show"
        :place="claimSheet.place"
    />

    <!-- ── Filter Bottom Sheet ── -->
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="filterSheet" class="absolute inset-0 bg-black/40 z-[150]" @click.self="filterSheet = false">
                <Transition
                    enter-active-class="transition duration-300 ease-out"
                    enter-from-class="translate-y-full"
                    enter-to-class="translate-y-0"
                    leave-active-class="transition duration-200 ease-in"
                    leave-from-class="translate-y-0"
                    leave-to-class="translate-y-full">
                    <div v-if="filterSheet" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl pb-10 max-h-[85vh] overflow-y-auto">

                        <!-- Handle + Header -->
                        <div class="sticky top-0 bg-white pt-3 pb-4 px-5 border-b border-gray-100 z-10">
                            <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-4"></div>
                            <div class="flex items-center justify-between">
                                <h3 class="text-base font-extrabold text-black">Filters</h3>
                                <div class="flex items-center gap-2">
                                    <button @click="resetFilters"
                                        class="flex items-center gap-1.5 text-xs font-bold text-gray-400 px-3 py-1.5 rounded-full bg-gray-100">
                                        <RotateCcw :size="12" />
                                        Reset
                                    </button>
                                    <button @click="filterSheet = false"
                                        class="w-8 h-8 flex items-center justify-center rounded-full bg-gray-100">
                                        <X :size="16" class="text-gray-500" />
                                    </button>
                                </div>
                            </div>
                        </div>

                        <div class="px-5 pt-5 space-y-6">

                            <!-- Sport Type -->
                            <div>
                                <p class="text-[11px] font-black text-gray-400 uppercase tracking-wider mb-3">Sport Type</p>
                                <div class="flex flex-wrap gap-2">
                                    <button v-for="c in categories" :key="c.id"
                                        @click="draftSport = c.id"
                                        class="flex items-center gap-2 h-9 px-4 rounded-full text-xs font-bold transition-all"
                                        :class="draftSport === c.id ? 'bg-black text-white shadow-md shadow-sm' : 'bg-gray-100 text-gray-500'">
                                        <component :is="c.icon" :size="13" :stroke-width="2.5" />
                                        {{ c.label }}
                                    </button>
                                </div>
                            </div>

                            <!-- Distance -->
                            <div>
                                <p class="text-[11px] font-black text-gray-400 uppercase tracking-wider mb-3">Search Radius</p>
                                <div class="flex gap-2 flex-wrap">
                                    <button v-for="r in RADIUS_OPTIONS" :key="r"
                                        @click="draftRadius = r"
                                        class="h-9 px-5 rounded-full text-xs font-bold transition-all"
                                        :class="draftRadius === r ? 'bg-black text-white' : 'bg-gray-100 text-gray-500'">
                                        {{ r }} km
                                    </button>
                                </div>
                            </div>

                            <!-- Apply -->
                            <button @click="applyFilters"
                                class="w-full bg-black text-white font-extrabold py-3.5 rounded-2xl text-sm active:scale-[0.98] transition-transform">
                                Apply Filters
                                <span v-if="draftSport !== 'All' || draftRadius !== 25" class="ml-1 opacity-70">
                                    ({{ (draftSport !== 'All' ? 1 : 0) + (draftRadius !== 25 ? 1 : 0) }} active)
                                </span>
                            </button>
                        </div>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>

    <!-- ── Location Picker Sheet ── -->
    <Teleport to="#app-root">
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="locPicker" class="absolute inset-0 bg-black/40 z-[150]" @click.self="locPicker = false">
                <Transition
                    enter-active-class="transition duration-300 ease-out"
                    enter-from-class="translate-y-full"
                    enter-to-class="translate-y-0"
                    leave-active-class="transition duration-200 ease-in"
                    leave-from-class="translate-y-0"
                    leave-to-class="translate-y-full">
                    <div v-if="locPicker" class="absolute bottom-0 inset-x-0 bg-white rounded-t-3xl px-5 pt-4 pb-10">
                        <div class="w-10 h-1 bg-slate-200 rounded-full mx-auto mb-5"></div>
                        <div class="flex items-center justify-between mb-5">
                            <h3 class="text-base font-extrabold text-black">Change Location</h3>
                            <button @click="locPicker = false"
                                class="w-8 h-8 flex items-center justify-center rounded-full bg-gray-100">
                                <X :size="16" class="text-gray-500" />
                            </button>
                        </div>
                        <!-- City input -->
                        <div class="relative mb-3">
                            <MapPin :size="16" class="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 z-10" />
                            <input
                                v-model="locInput"
                                @input="onLocInputChange"
                                @keyup.enter="applyLocInput(null, null, null)"
                                type="text"
                                placeholder="Enter city or area…"
                                autofocus
                                class="w-full pl-10 pr-10 py-3 rounded-2xl bg-white border border-gray-200 text-sm placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:border border-gray-200" />
                            <Loader2 v-if="locLoading" :size="15" class="absolute right-3.5 top-1/2 -translate-y-1/2 text-black animate-spin" />
                        </div>

                        <!-- Autocomplete suggestions -->
                        <div v-if="locSuggestions.length" class="mb-3 bg-white rounded-2xl overflow-hidden ring-1 ring-slate-100 shadow-sm">
                            <button
                                v-for="(s, i) in locSuggestions" :key="i"
                                @click="applyLocInput(s.label, s.lat, s.lng)"
                                class="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-white active:bg-gray-100 transition-colors border-b border-slate-50 last:border-0">
                                <MapPin :size="14" class="text-gray-400 shrink-0" />
                                <span class="text-sm text-gray-700 truncate">{{ s.label }}</span>
                            </button>
                        </div>

                        <button @click="applyLocInput(null, null, null)" :disabled="!locInput.trim()"
                            class="w-full bg-black text-white font-bold py-3 rounded-2xl text-sm mb-3 disabled:opacity-40 active:scale-[0.98] transition-transform">
                            Search This Location
                        </button>
                        <!-- GPS option -->
                        <button @click="useGpsFromPicker"
                            class="w-full flex items-center justify-center gap-2 bg-white border border-gray-200 text-gray-700 font-bold py-3 rounded-2xl text-sm active:bg-gray-100 transition-colors">
                            <MapPin :size="15" class="text-black" />
                            Use My GPS Location
                        </button>
                    </div>
                </Transition>
            </div>
        </Transition>
    </Teleport>
</template>
