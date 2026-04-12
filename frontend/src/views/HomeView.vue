<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import axios from 'axios'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import {
    Search, MapPin, SlidersHorizontal, Heart,
    Wind, CircleDot, Target, Flag, Activity, Layers3,
    Dumbbell, Waves, Swords, Loader2, Star, Flame, Map
} from 'lucide-vue-next'

const router = useRouter()
const auth   = useAuthStore()

const courts        = ref([])
const loading       = ref(true)
const searchText    = ref('')
const selectedSport = ref('All')
const locating      = ref(false)
const userLat       = ref(null)
const userLng       = ref(null)
const favorites     = ref(new Set())
const favLoading    = ref(new Set())

// ── Location detection ────────────────────────────────────────
const detectLocation = () => {
    if (!navigator.geolocation) return
    locating.value = true
    navigator.geolocation.getCurrentPosition(
        async (pos) => {
            try {
                const { latitude, longitude } = pos.coords
                userLat.value = latitude; userLng.value = longitude
                const res  = await fetch(
                    `https://nominatim.openstreetmap.org/reverse?lat=${latitude}&lon=${longitude}&format=json`,
                    { headers: { 'Accept-Language': 'en' } }
                )
                const data = await res.json()
                const city = data.address?.city || data.address?.town
                    || data.address?.village || data.address?.suburb || data.address?.county
                if (city) searchText.value = city
                fetchVenues()
            } catch { /* ignore */ }
            finally { locating.value = false }
        },
        () => { locating.value = false },
        { timeout: 8000 }
    )
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
const locationLabel = computed(() => {
    if (locating.value) return 'Detecting...'
    if (searchText.value) return (userLat.value ? 'Near ' : '') + searchText.value
    return 'Your Location'
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
        } else if (searchText.value) {
            p.set('location', searchText.value)
        }
        if (selectedSport.value !== 'All') p.set('type', selectedSport.value)
        const res = await axios.get('/courts' + (p.toString() ? '?' + p : ''))
        courts.value = res.data.records || []
    } catch { courts.value = [] }
    finally { loading.value = false }
}

onMounted(async () => {
    detectLocation()
    fetchVenues()
    if (auth.isLoggedIn) {
        try {
            const res = await axios.get(`/favorites?user_id=${auth.user?.id}`)
            favorites.value = new Set(res.data.ids || [])
        } catch { /* ignore */ }
    }
})

let timer = null
watch(searchText,    () => { clearTimeout(timer); timer = setTimeout(fetchVenues, 400) })
watch(selectedSport, fetchVenues)
</script>

<template>
    <div class="min-h-full bg-slate-50">

        <!-- Teleport contents to Global AppHeader -->
        <Teleport to="#header-subtitle">
            <div class="flex items-center gap-1.5 text-slate-400 mt-0.5">
                <MapPin :size="11" :stroke-width="2.5" class="text-primary/70 shrink-0" />
                <span class="text-[10px] font-bold uppercase tracking-wide truncate max-w-[150px]">{{ locationLabel }}</span>
            </div>
        </Teleport>

        <Teleport to="#header-extra">
            <!-- Search bar -->
            <div class="px-4 pb-3">
                <div class="flex h-11 items-stretch rounded-xl ring-1 ring-slate-200 bg-white shadow-sm">
                    <div class="flex items-center pl-3.5 text-slate-400">
                        <Search :size="16" :stroke-width="2.5" />
                    </div>
                    <input v-model="searchText" @input="onSearchInput"
                        type="search"
                        placeholder="Search courts, gyms, clubs..."
                        class="flex-1 px-3 text-sm bg-transparent border-none focus:ring-0 placeholder:text-slate-400" />
                    <button @click="detectLocation" :disabled="locating"
                        class="flex items-center justify-center pr-3.5 text-slate-400 disabled:opacity-50">
                        <Loader2 v-if="locating" :size="16" class="animate-spin text-primary" />
                        <SlidersHorizontal v-else :size="16" />
                    </button>
                </div>
            </div>

            <!-- Category chips -->
            <div class="flex gap-2.5 px-4 pb-4 overflow-x-auto scrollbar-hide">
                <button v-for="c in categories" :key="c.id" @click="selectedSport = c.id"
                    class="flex h-9 shrink-0 items-center gap-2 rounded-full px-4 text-xs font-bold transition-all duration-200"
                    :class="selectedSport === c.id ? 'bg-primary text-white shadow-md shadow-primary/20' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'">
                    <component :is="c.icon" :size="14" :stroke-width="2.5" />
                    {{ c.label }}
                </button>
            </div>
        </Teleport>

        <!-- ── Main content (scrollable) ── -->
        <main class="flex-1 px-4 py-4 pb-28">

            <!-- Section title -->
            <div class="flex items-center justify-between mb-4">
                <h2 class="text-[17px] font-extrabold text-slate-900">{{ sectionTitle }}</h2>
                <button class="text-xs font-bold text-primary bg-primary-light px-3 py-1.5 rounded-full">
                    See all
                </button>
            </div>

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
                <div class="w-16 h-16 bg-primary-light text-primary rounded-full flex items-center justify-center mb-4">
                    <Map :size="32" :stroke-width="2.5" />
                </div>
                <p class="font-extrabold text-slate-700 text-base">No venues found</p>
                <p class="text-sm text-slate-400 mt-1.5 max-w-[220px]">
                    Try searching a different city or selecting another category
                </p>
            </div>

            <!-- Venue cards -->
            <div v-else class="space-y-4">
                <div v-for="(venue, idx) in courts" :key="venue.id"
                    @click="router.push('/courts/' + venue.id)"
                    class="bg-white rounded-2xl overflow-hidden shadow-card hover:shadow-card-lg transition-shadow cursor-pointer group">

                    <!-- Image -->
                    <div class="relative h-44 w-full">
                        <img :src="getImage(venue)" :alt="venue.name"
                            class="w-full h-full object-cover group-hover:scale-[1.02] transition-transform duration-300"
                            loading="lazy"
                            onerror="this.src='https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80'" />

                        <!-- Gradient overlay -->
                        <div class="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent"></div>

                        <!-- Heart -->
                        <div @click.stop="toggleFavorite($event, venue.id)"
                            class="absolute top-3 right-3 w-9 h-9 bg-white/90 backdrop-blur rounded-full flex items-center justify-center shadow-sm cursor-pointer z-10 active:scale-90 transition-transform">
                            <Heart :size="16"
                                :class="favorites.has(venue.id) ? 'fill-red-500 text-red-500' : 'text-slate-400'" />
                        </div>

                        <!-- Type badge -->
                        <div class="absolute bottom-3 left-3 z-10">
                            <span class="bg-white/90 backdrop-blur text-slate-700 text-[10px] font-extrabold px-3.5 py-1.5 rounded-full tracking-wide uppercase flex items-center gap-1.5">
                                <component :is="categories.find(c => c.id === venue.type)?.icon" :size="11" :stroke-width="3" />
                                {{ categories.find(c => c.id === venue.type)?.label || venue.type }}
                            </span>
                        </div>

                        <!-- POPULAR badge (first card) -->
                        <div v-if="idx === 0" class="absolute top-3 left-3 z-10">
                            <span class="bg-primary text-white text-[10px] font-extrabold px-3 py-1.5 rounded-full tracking-wide flex items-center gap-1">
                                <Flame :size="11" :stroke-width="3" />
                                POPULAR
                            </span>
                        </div>
                    </div>

                    <!-- Card body -->
                    <div class="px-4 pt-3 pb-4">
                        <!-- Name + Rating -->
                        <div class="flex items-start justify-between gap-2 mb-1.5">
                            <h3 class="font-extrabold text-slate-900 text-[15px] leading-tight flex-1">{{ venue.name }}</h3>
                            <div class="flex items-center gap-1 bg-amber-50 px-2 py-0.5 rounded-lg shrink-0">
                                <Star :size="11" class="fill-amber-400 text-amber-400" />
                                <span class="text-xs font-extrabold text-amber-700">4.8</span>
                            </div>
                        </div>

                        <!-- Location -->
                        <div class="flex items-center gap-1 text-slate-400 text-xs mb-3.5">
                            <MapPin :size="11" class="shrink-0" />
                            <span class="truncate">{{ venue.location || 'Location not set' }}</span>
                            <span v-if="venue.distance_km != null" class="shrink-0">
                                · {{ venue.distance_km }} km
                            </span>
                        </div>

                        <!-- Price + CTA -->
                        <div class="flex items-center justify-between">
                            <div>
                                <p class="text-[10px] text-slate-400 font-medium">Starting at</p>
                                <p class="text-primary font-extrabold text-[17px] leading-tight">
                                    ₹{{ venue.hourly_rate }}<span class="text-xs font-medium text-slate-400">/hr</span>
                                </p>
                            </div>
                            <button @click.stop="router.push('/courts/' + venue.id)"
                                class="bg-primary text-white text-xs font-extrabold px-5 py-2.5 rounded-xl shadow-sm hover:bg-primary-dark active:scale-95 transition-all">
                                Book Now
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </main>
    </div>
</template>
