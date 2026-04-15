<script setup>
import { ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { useRouter, useRoute } from 'vue-router'
import KoLogo from '@/components/KoLogo.vue'
import ChatSheet from '../components/ChatSheet.vue'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    Plus, X, Check, Clock,
    Wind, Flag, Target, Activity, CircleDot, Layers3, Dumbbell, Waves, Swords,
    IndianRupee, LocateFixed, Loader2, Sun, Moon, Shield,
    Camera, Trash2, TrendingUp, CalendarDays, Search, MapPin,
    Flame, Map, Globe, Heart, User, Star, LayoutGrid, Wallet, ArrowDownToLine, MessageSquare,
    ChevronLeft, ChevronRight
} from 'lucide-vue-next'

const router = useRouter()
const route  = useRoute()
const auth = useAuthStore()
const toast = useToastStore()

const activeFilter = ref('all')
const activeNavTab = ref('explore')
const courts = ref([])
const bookings = ref([])
const loading = ref(true)
const showAddForm = ref(false)
const searchQuery = ref('')

const AMENITIES_LIST = ['Parking', 'Floodlights', 'Changing Room', 'Shower', 'Equipment Rental', 'Cafeteria', 'WiFi', 'First Aid']

const newCourt = ref({
    name: '', location: '', type: 'shuttle', hourly_rate: '', description: '',
    image_url: '',
    lat: null, lng: null,
    open_time: '06:00', close_time: '22:00',
    morning_peak_start: '05:00', morning_peak_end: '09:00',
    evening_peak_start: '17:00', evening_peak_end: '21:00',
    peak_members_only: false,
    amenities: [],
})

const imagePreview = ref(null)
const uploadLoading = ref(false)

const handleImageSelect = async (event) => {
    const file = event.target.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (e) => { imagePreview.value = e.target.result }
    reader.readAsDataURL(file)
    uploadLoading.value = true
    try {
        const formData = new FormData()
        formData.append('image', file)
        const res = await axios.post('/upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        })
        newCourt.value.image_url = res.data.url
    } catch {
        toast.error('Photo upload failed')
        imagePreview.value = null
        newCourt.value.image_url = ''
    } finally {
        uploadLoading.value = false
    }
}

const clearImage = () => {
    imagePreview.value = null
    newCourt.value.image_url = ''
}

// Edit court — navigate to dedicated page
const editImagePreview = ref(null)   // kept for compat, unused
const editUploadLoading = ref(false) // kept for compat, unused

const hasPeakHours = computed(() => newCourt.value.type !== 'turf' && newCourt.value.type !== 'cricket')
const addLoading    = ref(false)
const geoLoading    = ref(false)
const editCourt     = ref(null)   // court being edited (null = closed)
const editLoading   = ref(false)
const deleteLoading = ref(null)   // court id being deleted

const geocodeLocation = async (text) => {
    if (!text.trim()) return null
    try {
        const res = await fetch(
            `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(text)}&format=json&limit=1`,
            { headers: { 'Accept-Language': 'en' } }
        )
        const data = await res.json()
        if (data.length > 0) return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
    } catch {}
    return null
}

const detectCourtLocation = () => {
    if (!navigator.geolocation) { toast.error('Geolocation not supported'); return }
    geoLoading.value = true
    navigator.geolocation.getCurrentPosition(
        async (pos) => {
            const { latitude, longitude } = pos.coords
            newCourt.value.lat = latitude
            newCourt.value.lng = longitude
            try {
                const res = await fetch(
                    `https://nominatim.openstreetmap.org/reverse?lat=${latitude}&lon=${longitude}&format=json`,
                    { headers: { 'Accept-Language': 'en' } }
                )
                const d = await res.json()
                const suburb = d.address?.suburb || d.address?.neighbourhood || ''
                const city   = d.address?.city   || d.address?.town || d.address?.village || ''
                newCourt.value.location = [suburb, city].filter(Boolean).join(', ')
            } catch {}
            geoLoading.value = false
            toast.success('Location pinned!')
        },
        () => { geoLoading.value = false; toast.error('Location permission denied') },
        { timeout: 8000 }
    )
}

const sportFilters = [
    { id: 'all',      label: 'All',        icon: LayoutGrid },
    { id: 'shuttle',  label: 'Badminton',  icon: Wind },
    { id: 'turf',     label: 'Football',   icon: Flag },
    { id: 'gym',      label: 'Gym',        icon: Dumbbell },
    { id: 'tennis',   label: 'Tennis',     icon: Activity },
    { id: 'cricket',  label: 'Cricket',    icon: Target },
    { id: 'swimming', label: 'Swimming',   icon: Waves },
    { id: 'boxing',   label: 'Boxing',     icon: Swords },
    { id: 'basket',   label: 'Basketball', icon: CircleDot },
]

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

const sportRating = {
    shuttle: '4.8', turf: '4.9', gym: '4.7', cricket: '4.6',
    tennis: '4.8', swimming: '4.7', boxing: '4.6', basket: '4.7', other: '4.5'
}

const filteredCourts = computed(() => {
    let list = courts.value
    if (activeFilter.value !== 'all') {
        list = list.filter(c => c.type === activeFilter.value)
    }
    if (searchQuery.value.trim()) {
        const q = searchQuery.value.toLowerCase()
        list = list.filter(c =>
            c.name?.toLowerCase().includes(q) ||
            c.location?.toLowerCase().includes(q) ||
            c.type?.toLowerCase().includes(q)
        )
    }
    return list
})

const totalRevenue = computed(() =>
    bookings.value.filter(b => b.status !== 'cancelled').reduce((sum, b) => sum + parseFloat(b.total_price || 0), 0)
)

const todayBookings = computed(() => {
    const today = new Date().toISOString().slice(0, 10)
    return bookings.value.filter(b => b.start_time?.startsWith(today))
})

const formatTime = (dt) => new Date(dt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })

// ── Owner Reviews ─────────────────────────────────────────────────────────────
const ownerReviews   = ref([])
const reviewsLoading = ref(false)
const replyTexts     = ref({})    // { [review.id]: string }
const replyLoading   = ref(null)  // review.id being submitted

const fetchOwnerReviews = async () => {
    reviewsLoading.value = true
    try {
        const res = await axios.get(`/reviews?owner_id=${auth.user?.id}`)
        ownerReviews.value = res.data.records || []
    } catch { ownerReviews.value = [] }
    finally { reviewsLoading.value = false }
}

const submitReply = async (review) => {
    const text = (replyTexts.value[review.id] || '').trim()
    if (!text) return
    replyLoading.value = review.id
    try {
        await axios.put(`/reviews/${review.id}/reply`, { owner_id: auth.user?.id, reply: text })
        review.owner_reply = text
        review.owner_reply_at = new Date().toISOString()
        replyTexts.value[review.id] = ''
        toast.success('Reply saved!')
    } catch { toast.error('Could not save reply') }
    finally { replyLoading.value = null }
}

// ── Earnings ──────────────────────────────────────────────────────────────────
const earnings = ref(null)
const earningsLoading = ref(false)

const fetchEarnings = async () => {
    earningsLoading.value = true
    try {
        const res = await axios.get(`/earnings?owner_id=${auth.user?.id}`)
        earnings.value = res.data
    } catch {
        earnings.value = null
    } finally {
        earningsLoading.value = false
    }
}

const formatDate = (d) => new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })

const fetchData = async () => {
    loading.value = true
    try {
        const [courtsRes, bookingsRes] = await Promise.all([
            axios.get(`/courts?owner_id=${auth.user?.id}`),
            axios.get(`/bookings?owner_id=${auth.user?.id}`),
        ])
        courts.value = courtsRes.data.records || []
        bookings.value = bookingsRes.data.records || []
    } catch {
        courts.value = []
        bookings.value = []
    } finally {
        loading.value = false
    }
}

onMounted(() => {
    if (!auth.isLoggedIn) {
        router.push('/login')
        return
    }
    // Support ?tab=earnings or ?tab=reviews deep-link from Profile page
    const tab = route.query.tab
    if (tab === 'earnings') { activeNavTab.value = 'earnings'; fetchEarnings() }
    else if (tab === 'reviews') { activeNavTab.value = 'reviews'; fetchOwnerReviews() }
    fetchData()
})

const addCourt = async () => {
    if (!newCourt.value.name || !newCourt.value.hourly_rate) {
        toast.error('Service name and rate are required')
        return
    }
    addLoading.value = true
    try {
        if (!newCourt.value.lat && newCourt.value.location) {
            const coords = await geocodeLocation(newCourt.value.location)
            if (coords) { newCourt.value.lat = coords.lat; newCourt.value.lng = coords.lng }
        }
        await axios.post('/courts', { ...newCourt.value, owner_id: auth.user?.id })
        toast.success('Service listed successfully!')
        newCourt.value = {
            name: '', location: '', type: 'shuttle', hourly_rate: '', description: '',
            image_url: '', lat: null, lng: null,
            open_time: '06:00', close_time: '22:00',
            morning_peak_start: '05:00', morning_peak_end: '09:00',
            evening_peak_start: '17:00', evening_peak_end: '21:00',
            peak_members_only: false, amenities: [],
        }
        imagePreview.value = null
        showAddForm.value = false
        fetchData()
    } catch {
        toast.error('Failed to add service. Please try again.')
    } finally {
        addLoading.value = false
    }
}

const openEdit = (court) => {
    router.push(`/my-services/${court.id}/edit`)
}

const saveEdit = async () => {} // unused — handled by EditServiceView

const deleteCourt = async (court) => {
    if (!confirm(`Delete "${court.name}"? This cannot be undone.`)) return
    deleteLoading.value = court.id
    try {
        await axios.delete(`/courts/${court.id}`, { data: { owner_id: auth.user?.id } })
        toast.success('Service deleted')
        fetchData()
    } catch { toast.error('Delete failed') }
    finally { deleteLoading.value = null }
}

// ── Owner Chat ────────────────────────────────────────────────────────────────
const ownerChat = ref({ show: false, bookingId: null, playerId: null, playerName: '', courtName: '' })
const openOwnerChat = (booking) => {
    ownerChat.value = {
        show: true,
        bookingId: booking.id,
        playerId: booking.user_id,
        playerName: booking.user_name || 'Player',
        courtName: booking.court_name || '',
    }
}

const firstName = computed(() => auth.user?.name?.split(' ')[0] || 'there')
const userInitials = computed(() => {
    const parts = (auth.user?.name || 'User').split(' ')
    return parts.map(p => p[0]).join('').toUpperCase().slice(0, 2)
})

const avatarLoading = ref(false)
const handleAvatarUpload = async (event) => {
    const file = event.target.files[0]
    if (!file) return
    avatarLoading.value = true
    try {
        const formData = new FormData()
        formData.append('image', file)
        const res = await axios.post('/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
        auth.updateAvatar(res.data.url)
        toast.success('Profile photo updated!')
    } catch {
        toast.error('Failed to upload photo')
    } finally {
        avatarLoading.value = false
        event.target.value = ''
    }
}
</script>

<template>
    <!-- Outer wrapper matching reference: max-w-md centered, white card, full-screen -->
    <div class="max-w-md mx-auto bg-white min-h-screen flex flex-col shadow-xl relative">

        <!-- Teleport contents to Global Header -->
        <Teleport to="#header-extra">
            <!-- Search bar -->
            <div class="px-4 pb-3">
                <div class="flex h-11 items-stretch rounded-xl ring-1 ring-slate-200 bg-white shadow-sm focus-within:ring-primary/50 transition-all">
                    <div class="flex items-center pl-3.5 text-slate-400">
                        <Search :size="16" :stroke-width="2.5" />
                    </div>
                    <input
                        v-model="searchQuery"
                        class="flex-1 min-w-0 border-none bg-transparent focus:outline-none focus:ring-0 text-[13px] font-semibold text-slate-900 placeholder:text-slate-400 px-3"
                        placeholder="Search your services..."
                    />
                    <div class="flex items-center pr-3.5 text-slate-400">
                        <TrendingUp :size="16" />
                    </div>
                </div>
            </div>

            <!-- Sport filter chips  -->
            <div class="flex gap-3 px-4 pb-4 overflow-x-auto" style="-ms-overflow-style:none;scrollbar-width:none;">
                <button
                    v-for="f in sportFilters"
                    :key="f.id"
                    @click="activeFilter = f.id"
                    :class="activeFilter === f.id
                        ? 'bg-primary text-white shadow-md shadow-primary/20'
                        : 'bg-slate-100 text-slate-700'"
                    class="flex h-9 shrink-0 items-center justify-center gap-x-2 rounded-full px-4 transition-all">
                    <component :is="f.icon" :size="14" :stroke-width="2.5" />
                    <p class="text-xs font-bold">{{ f.label }}</p>
                </button>
            </div>
        </Teleport>

        <!-- ── MAIN CONTENT ── -->
        <main class="flex-1 px-4 pb-28">

            <!-- Section header -->
            <div class="flex items-center justify-between pt-4 pb-3">
                <h3 class="text-slate-900 text-xl font-bold tracking-tight">
                    {{ activeNavTab === 'bookings' ? 'All Bookings' : activeNavTab === 'reviews' ? 'Reviews' : activeNavTab === 'earnings' ? 'Earnings' : activeNavTab === 'profile' ? 'Profile' : 'My Services' }}
                </h3>
                <button v-if="activeNavTab === 'explore'"
                    @click="showAddForm = true"
                    class="text-primary text-sm font-semibold">
                    + Add Service
                </button>
            </div>

            <!-- LOADING skeleton -->
            <div v-if="loading" class="space-y-6">
                <div v-for="i in 3" :key="i" class="rounded-xl overflow-hidden shadow-sm ring-1 ring-slate-100 animate-pulse">
                    <div class="h-48 bg-slate-200 w-full"></div>
                    <div class="p-4 space-y-2">
                        <div class="h-4 bg-slate-200 rounded w-2/3"></div>
                        <div class="h-3 bg-slate-200 rounded w-1/2"></div>
                    </div>
                </div>
            </div>

            <!-- EXPLORE / COURTS TAB -->
            <template v-else-if="activeNavTab === 'explore'">
                <!-- Empty state -->
                <div v-if="filteredCourts.length === 0" class="text-center py-20 bg-slate-50/50 rounded-3xl border-2 border-dashed border-slate-100">
                    <div class="w-16 h-16 bg-white rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-sm">
                        <Map :size="32" :stroke-width="2" class="text-slate-300" />
                    </div>
                    <p class="font-extrabold text-slate-700 text-lg">No services yet</p>
                    <p class="text-sm text-slate-400 mt-1 mb-6">Services you list will appear here</p>
                    <button @click="showAddForm = true"
                        class="bg-primary text-white font-bold py-3 px-8 rounded-xl shadow-fab">
                        Add Service
                    </button>
                </div>

                <!-- Court cards - matching reference design exactly -->
                <div v-else class="space-y-6">
                    <div
                        v-for="(court, idx) in filteredCourts"
                        :key="court.id"
                        class="flex flex-col bg-white rounded-xl overflow-hidden shadow-sm hover:shadow-md transition-shadow ring-1 ring-slate-100">

                        <!-- Image section -->
                        <div class="relative h-48 w-full bg-slate-200">
                            <img
                                v-if="court.image_url"
                                :src="court.image_url"
                                class="w-full h-full object-cover"
                                onerror="this.style.display='none'" />
                            <!-- Placeholder gradient when no image -->
                            <div v-else class="w-full h-full flex items-center justify-center bg-slate-100">
                                <component :is="sportOptions.find(s => s.id === court.type)?.icon || LayoutGrid" :size="48" :stroke-width="1.5" class="text-slate-300" />
                            </div>
                            <!-- Favorite heart button -->
                            <div class="absolute top-3 right-3 bg-white/95 backdrop-blur rounded-full p-2 shadow-sm border border-slate-100">
                                <Heart :size="16" :stroke-width="2.5" class="text-slate-400" />
                            </div>
                            <!-- POPULAR badge for first court or high-revenue courts -->
                            <div v-if="idx === 0" class="absolute bottom-3 left-3 bg-primary text-white text-[10px] font-bold px-2.5 py-1.5 rounded-lg flex items-center gap-1 shadow-lg shadow-primary/30 tracking-wider">
                                <Flame :size="10" :stroke-width="3" />
                                POPULAR
                            </div>
                        </div>

                        <!-- Card body -->
                        <div class="p-4">
                            <!-- Name + Rating -->
                            <div class="flex justify-between items-start mb-1">
                                <h4 class="text-slate-900 font-bold text-lg">{{ court.name }}</h4>
                                <div class="flex items-center gap-1 bg-amber-50 px-2 py-1 rounded-lg text-amber-700 font-bold text-[11px] border border-amber-100/50">
                                    <Star :size="11" :stroke-width="2.5" class="fill-amber-500 text-amber-500" />
                                    {{ sportRating[court.type] || '4.8' }}
                                </div>
                            </div>
                            <!-- Location -->
                            <div class="flex items-center gap-1.5 text-slate-500 text-sm mb-4">
                                <MapPin :size="12" :stroke-width="2.5" class="text-slate-400" />
                                <span>{{ court.location || 'Location not set' }}</span>
                            </div>
                            <!-- Price + Action -->
                            <div class="flex items-center justify-between">
                                <div class="flex flex-col">
                                    <span class="text-xs text-slate-400 font-medium">Starting at</span>
                                    <span class="text-primary font-bold text-lg">
                                        ₹{{ court.hourly_rate }}<span class="text-sm font-normal text-slate-500">/hr</span>
                                    </span>
                                </div>
                                <div class="flex gap-2">
                                    <button @click.stop="openEdit(court)"
                                        class="bg-slate-100 text-slate-600 font-bold py-2.5 px-4 rounded-xl text-xs hover:bg-slate-200 transition-colors">
                                        Edit
                                    </button>
                                    <button @click.stop="deleteCourt(court)" :disabled="deleteLoading === court.id"
                                        class="bg-red-50 text-red-500 font-bold py-2.5 px-4 rounded-xl text-xs hover:bg-red-100 transition-colors disabled:opacity-50">
                                        <span v-if="deleteLoading === court.id" class="w-3 h-3 border-2 border-red-300 border-t-red-500 rounded-full animate-spin inline-block"></span>
                                        <span v-else>Del</span>
                                    </button>
                                    <RouterLink :to="`/my-services/${court.id}/plans`"
                                        class="bg-primary hover:bg-primary-dark text-white font-bold py-2.5 px-4 rounded-xl text-xs transition-colors">
                                        Plans
                                    </RouterLink>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </template>

            <!-- BOOKINGS TAB -->
            <template v-else-if="activeNavTab === 'bookings'">
                <div v-if="bookings.length === 0" class="text-center py-20 bg-slate-50/50 rounded-3xl border-2 border-dashed border-slate-100 mx-4">
                    <div class="w-16 h-16 bg-white rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-sm">
                        <CalendarDays :size="32" :stroke-width="2" class="text-slate-300" />
                    </div>
                    <p class="font-extrabold text-slate-700 text-lg">No bookings yet</p>
                    <p class="text-sm text-slate-400 mt-1">Bookings for your services will appear here</p>
                </div>
                <div v-else class="space-y-4">
                    <div
                        v-for="booking in bookings"
                        :key="booking.id"
                        class="flex flex-col bg-white rounded-xl overflow-hidden shadow-sm ring-1 ring-slate-100 p-4">
                        <div class="flex items-start gap-3">
                            <div class="shrink-0 w-12 h-12 bg-primary rounded-xl flex flex-col items-center justify-center text-white">
                                <span class="text-base font-bold leading-none">{{ new Date(booking.start_time).getDate() }}</span>
                                <span class="text-[9px] font-semibold uppercase">{{ new Date(booking.start_time).toLocaleDateString('en-IN', { month: 'short' }) }}</span>
                            </div>
                            <div class="flex-1 min-w-0">
                                <p class="font-bold text-slate-900 text-sm truncate">{{ booking.court_name }}</p>
                                <div class="flex items-center gap-1 text-xs text-slate-500 mt-0.5">
                                    <Clock :size="10" />
                                    {{ formatTime(booking.start_time) }} – {{ formatTime(booking.end_time) }}
                                </div>
                                <div class="flex items-center justify-between mt-2">
                                    <span
                                        :class="booking.status === 'confirmed' ? 'text-primary bg-primary-light' : 'text-amber-600 bg-amber-50'"
                                        class="text-[10px] font-bold px-2 py-1 rounded-full capitalize">
                                        {{ booking.status }}
                                    </span>
                                    <div class="flex items-center gap-2">
                                        <span class="font-bold text-sm text-slate-800">₹{{ booking.total_price }}</span>
                                        <button v-if="booking.user_id" @click="openOwnerChat(booking)"
                                            class="flex items-center gap-1 text-[11px] font-bold px-2.5 py-1.5 rounded-xl bg-slate-100 text-slate-600 active:bg-slate-200 transition-colors">
                                            <MessageSquare :size="11" />
                                            Chat
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </template>

            <!-- EARNINGS TAB -->
            <template v-else-if="activeNavTab === 'earnings'">
                <div v-if="earningsLoading" class="space-y-3">
                    <div v-for="i in 4" :key="i" class="bg-white rounded-xl p-4 animate-pulse ring-1 ring-slate-100">
                        <div class="h-4 bg-slate-200 rounded w-1/2 mb-2"></div>
                        <div class="h-6 bg-slate-200 rounded w-1/3"></div>
                    </div>
                </div>

                <template v-else-if="earnings">
                    <!-- Summary cards -->
                    <div class="grid grid-cols-2 gap-3 mb-5">
                        <div class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 shadow-sm col-span-2">
                            <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-1">Total Earned</p>
                            <p class="text-3xl font-extrabold text-slate-900">₹{{ Number(earnings.summary.total_earned).toLocaleString('en-IN') }}</p>
                        </div>
                        <div class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 shadow-sm">
                            <p class="text-[11px] font-semibold text-slate-400 mb-1">This Week</p>
                            <p class="text-xl font-bold text-primary">₹{{ Number(earnings.summary.this_week).toLocaleString('en-IN') }}</p>
                        </div>
                        <div class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 shadow-sm">
                            <p class="text-[11px] font-semibold text-slate-400 mb-1">This Month</p>
                            <p class="text-xl font-bold text-primary">₹{{ Number(earnings.summary.this_month).toLocaleString('en-IN') }}</p>
                        </div>
                        <div class="bg-emerald-50 rounded-2xl p-4 ring-1 ring-emerald-100 shadow-sm">
                            <p class="text-[11px] font-semibold text-emerald-600 mb-1">Pending Payout</p>
                            <p class="text-xl font-bold text-emerald-700">₹{{ Number(earnings.summary.pending_payout).toLocaleString('en-IN') }}</p>
                        </div>
                        <div class="bg-slate-50 rounded-2xl p-4 ring-1 ring-slate-100 shadow-sm">
                            <p class="text-[11px] font-semibold text-slate-400 mb-1">Paid Out</p>
                            <p class="text-xl font-bold text-slate-600">₹{{ Number(earnings.summary.total_paid_out).toLocaleString('en-IN') }}</p>
                        </div>
                    </div>

                    <!-- Recent transactions -->
                    <h2 class="section-title mb-3">Recent Transactions</h2>
                    <div v-if="earnings.transactions.length === 0" class="text-center py-10 text-slate-400 text-sm">
                        No paid transactions yet
                    </div>
                    <div v-else class="space-y-2 mb-5">
                        <div v-for="tx in earnings.transactions" :key="tx.id"
                            class="bg-white rounded-xl p-4 ring-1 ring-slate-100 flex items-center gap-3">
                            <div class="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                                :class="tx.type === 'subscription' ? 'bg-violet-50' : 'bg-primary-light'">
                                <IndianRupee :size="16" :class="tx.type === 'subscription' ? 'text-violet-600' : 'text-primary'" />
                            </div>
                            <div class="flex-1 min-w-0">
                                <p class="font-semibold text-sm text-slate-800 truncate">{{ tx.customer_name }}</p>
                                <p class="text-xs text-slate-400 truncate">{{ tx.court_name }} · {{ tx.type }}</p>
                            </div>
                            <div class="text-right shrink-0">
                                <p class="font-bold text-sm text-slate-900">₹{{ Number(tx.amount).toLocaleString('en-IN') }}</p>
                                <p class="text-[10px] text-slate-400">{{ formatDate(tx.created_at) }}</p>
                            </div>
                        </div>
                    </div>

                    <!-- Payout history -->
                    <h2 class="section-title mb-3">Payout History</h2>
                    <div v-if="earnings.payouts.length === 0"
                        class="text-center py-8 bg-slate-50 rounded-2xl border border-dashed border-slate-200 text-sm text-slate-400">
                        No payouts recorded yet.<br>
                        <span class="text-xs">Payouts are transferred weekly by the platform.</span>
                    </div>
                    <div v-else class="space-y-2">
                        <div v-for="payout in earnings.payouts" :key="payout.id"
                            class="bg-white rounded-xl p-4 ring-1 ring-slate-100 flex items-center gap-3">
                            <div class="w-10 h-10 rounded-full bg-emerald-50 flex items-center justify-center shrink-0">
                                <ArrowDownToLine :size="16" class="text-emerald-600" />
                            </div>
                            <div class="flex-1 min-w-0">
                                <p class="font-semibold text-sm text-slate-800">Payout</p>
                                <p v-if="payout.note" class="text-xs text-slate-400 truncate">{{ payout.note }}</p>
                            </div>
                            <div class="text-right shrink-0">
                                <p class="font-bold text-sm text-emerald-700">₹{{ Number(payout.amount).toLocaleString('en-IN') }}</p>
                                <p class="text-[10px] text-slate-400">{{ formatDate(payout.paid_at) }}</p>
                            </div>
                        </div>
                    </div>
                    <!-- View full ledger -->
                    <button @click="router.push('/ledger')"
                        class="w-full mt-4 py-3 rounded-xl border-2 border-dashed border-primary/30 text-primary font-semibold text-sm flex items-center justify-center gap-2">
                        <IndianRupee :size="15" />
                        View Full Ledger
                    </button>
                </template>

                <div v-else class="text-center py-20 text-slate-400 text-sm">
                    Failed to load earnings. Pull to refresh.
                </div>
            </template>

            <!-- REVIEWS TAB -->
            <template v-else-if="activeNavTab === 'reviews'">
                <div v-if="reviewsLoading" class="space-y-3">
                    <div v-for="i in 3" :key="i" class="bg-white rounded-xl p-4 animate-pulse ring-1 ring-slate-100">
                        <div class="h-3 bg-slate-200 rounded w-2/5 mb-2"></div>
                        <div class="h-4 bg-slate-200 rounded w-4/5"></div>
                    </div>
                </div>
                <div v-else-if="ownerReviews.length === 0"
                    class="text-center py-20 bg-slate-50/50 rounded-3xl border-2 border-dashed border-slate-100">
                    <Star :size="36" class="text-slate-300 mx-auto mb-3" />
                    <p class="font-bold text-slate-600">No reviews yet</p>
                    <p class="text-sm text-slate-400 mt-1">Player reviews will appear here</p>
                </div>
                <div v-else class="space-y-4">
                    <div v-for="review in ownerReviews" :key="review.id"
                        class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 shadow-sm">
                        <!-- Court + date -->
                        <div class="flex items-center justify-between mb-2">
                            <span class="text-[11px] font-bold text-primary bg-primary-light px-2.5 py-1 rounded-full">{{ review.court_name }}</span>
                            <span class="text-[10px] text-slate-400">{{ new Date(review.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) }}</span>
                        </div>
                        <!-- Reviewer + stars -->
                        <div class="flex items-center justify-between mb-2">
                            <span class="text-sm font-semibold text-slate-800">{{ review.user_name }}</span>
                            <div class="flex gap-0.5">
                                <Star v-for="n in 5" :key="n" :size="11"
                                    :class="n <= review.rating ? 'fill-amber-400 text-amber-400' : 'fill-slate-200 text-slate-200'" />
                            </div>
                        </div>
                        <p v-if="review.comment" class="text-sm text-slate-500 leading-relaxed mb-3">{{ review.comment }}</p>

                        <!-- Existing reply -->
                        <div v-if="review.owner_reply"
                            class="bg-slate-50 rounded-xl px-3 py-2.5 border-l-2 border-primary/40 mb-2">
                            <p class="text-[10px] font-bold text-primary mb-1">Your Response</p>
                            <p class="text-xs text-slate-600">{{ review.owner_reply }}</p>
                        </div>

                        <!-- Reply form -->
                        <div v-if="!review.owner_reply" class="mt-2">
                            <textarea v-model="replyTexts[review.id]" rows="2"
                                placeholder="Write a reply..."
                                class="w-full text-sm rounded-xl bg-slate-50 border border-slate-200 px-3 py-2 resize-none focus:ring-2 focus:ring-primary/20 outline-none placeholder:text-slate-300 mb-2">
                            </textarea>
                            <button @click="submitReply(review)"
                                :disabled="!replyTexts[review.id]?.trim() || replyLoading === review.id"
                                class="w-full py-2.5 rounded-xl bg-primary text-white text-sm font-bold disabled:opacity-40 flex items-center justify-center gap-1.5">
                                <Loader2 v-if="replyLoading === review.id" :size="14" class="animate-spin" />
                                <span v-else>Reply</span>
                            </button>
                        </div>
                    </div>
                </div>
            </template>

            <!-- PROFILE TAB -->
            <template v-else-if="activeNavTab === 'profile'">
                <div class="bg-white rounded-xl p-6 ring-1 ring-slate-100 shadow-sm">
                    <div class="flex flex-col items-center text-center mb-6">
                        <!-- Tappable avatar -->
                        <div class="relative mb-3">
                            <div class="size-20 rounded-full overflow-hidden bg-primary flex items-center justify-center">
                                <img v-if="auth.user?.avatar_url" :src="auth.user.avatar_url" class="w-full h-full object-cover" />
                                <span v-else class="text-white text-2xl font-bold">{{ userInitials }}</span>
                            </div>
                            <label class="absolute -bottom-1 -right-1 w-7 h-7 bg-primary rounded-full flex items-center justify-center cursor-pointer border-2 border-white shadow">
                                <Camera :size="13" class="text-white" />
                                <input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" @change="handleAvatarUpload" />
                            </label>
                            <div v-if="avatarLoading" class="absolute inset-0 rounded-full bg-black/40 flex items-center justify-center">
                                <Loader2 :size="22" class="text-white animate-spin" />
                            </div>
                        </div>
                        <h2 class="text-xl font-bold text-slate-900">{{ auth.user?.name }}</h2>
                        <p class="text-sm text-slate-500 mt-0.5">{{ auth.user?.phone }}</p>
                        <span class="mt-2 bg-primary-light text-primary text-xs font-bold px-3 py-1 rounded-full">KoCourt Member</span>
                    </div>
                    <!-- Quick stats -->
                    <div class="grid grid-cols-3 gap-3 mb-6">
                        <div class="bg-slate-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-bold text-slate-900">{{ courts.length }}</p>
                            <p class="text-[11px] text-slate-500 font-medium">Services</p>
                        </div>
                        <div class="bg-slate-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-bold text-slate-900">{{ bookings.length }}</p>
                            <p class="text-[11px] text-slate-500 font-medium">Bookings</p>
                        </div>
                        <div class="bg-slate-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-bold text-slate-900">{{ (totalRevenue/1000).toFixed(1) }}K</p>
                            <p class="text-[11px] text-slate-500 font-medium">Revenue</p>
                        </div>
                    </div>
                    <button
                        @click="auth.logout(); router.push('/')"
                        class="w-full py-3 rounded-xl bg-red-50 text-red-600 font-bold text-sm">
                        Sign Out
                    </button>
                </div>
            </template>

        </main>

        <!-- ── BOTTOM NAV (fixed, matching reference exactly) ── -->
        <nav class="fixed bottom-0 left-0 right-0 max-w-md mx-auto bg-white/95 backdrop-blur border-t border-slate-100 px-6 py-3 flex justify-between items-center z-20">
            <button
                @click="activeNavTab = 'explore'"
                :class="activeNavTab === 'explore' ? 'text-primary' : 'text-slate-400'"
                class="flex flex-col items-center gap-1.5 px-2">
                <Globe :size="20" :stroke-width="2.5" />
                <span class="text-[10px] font-bold tracking-tight">Explore</span>
            </button>

            <button
                @click="activeNavTab = 'bookings'"
                :class="activeNavTab === 'bookings' ? 'text-primary' : 'text-slate-400'"
                class="flex flex-col items-center gap-1.5 px-2 relative">
                <CalendarDays :size="20" :stroke-width="2.5" />
                <span class="text-[10px] font-bold tracking-tight">Bookings</span>
                <span v-if="todayBookings.length"
                    class="absolute -top-1 -right-0.5 bg-red-500 text-white text-[8px] font-bold w-3.5 h-3.5 rounded-full flex items-center justify-center border-2 border-white">
                    {{ todayBookings.length }}
                </span>
            </button>

            <!-- Centre FAB -->
            <div class="flex flex-col items-center -mt-8">
                <button
                    @click="showAddForm = true"
                    class="bg-primary text-white size-14 rounded-full shadow-fab flex items-center justify-center border-4 border-white">
                    <Plus :size="28" />
                </button>
            </div>

            <button
                @click="activeNavTab = 'profile'"
                :class="activeNavTab === 'profile' ? 'text-primary' : 'text-slate-400'"
                class="flex flex-col items-center gap-1.5 px-2">
                <User :size="20" :stroke-width="2.5" />
                <span class="text-[10px] font-bold tracking-tight">Profile</span>
            </button>
        </nav>

        <!-- ── ADD COURT MODAL (bottom sheet) ── -->
        <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="showAddForm" class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-end">
                <div class="bg-white w-full rounded-t-3xl max-h-[92vh] overflow-y-auto">
                    <!-- Sheet header -->
                    <div class="sticky top-0 bg-white px-5 py-4 border-b border-slate-100 flex items-center justify-between rounded-t-3xl">
                        <h2 class="text-base font-bold text-slate-900">Add New Service</h2>
                        <button @click="showAddForm = false" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                            <X :size="18" class="text-slate-500" />
                        </button>
                    </div>

                    <div class="px-5 py-5 space-y-4 pb-10">
                        <!-- Court Name -->
                        <div>
                            <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Service Name *</label>
                            <input v-model="newCourt.name" type="text" placeholder="e.g. Champions Badminton Arena"
                                class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                        </div>
                        <!-- Location -->
                        <div>
                            <div class="flex items-center justify-between mb-2">
                                <label class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Location</label>
                                <button @click="detectCourtLocation" :disabled="geoLoading"
                                    class="flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-lg transition-colors"
                                    :class="newCourt.lat ? 'bg-primary-light text-primary' : 'bg-slate-100 text-slate-500 hover:bg-primary-light hover:text-primary'">
                                    <Loader2 v-if="geoLoading" :size="12" class="animate-spin" />
                                    <LocateFixed v-else :size="12" />
                                    {{ newCourt.lat ? 'GPS pinned ✓' : 'Use GPS' }}
                                </button>
                            </div>
                            <input v-model="newCourt.location" type="text" placeholder="e.g. Velachery, Chennai"
                                class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                            <p v-if="newCourt.lat" class="text-[11px] text-primary mt-1.5 font-medium">
                                📍 Coordinates saved — players can find this court by proximity
                            </p>
                        </div>
                        <!-- Sport Type -->
                        <div>
                            <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Sport Type</label>
                            <div class="grid grid-cols-3 gap-2">
                                <button
                                    v-for="sport in sportOptions"
                                    :key="sport.id"
                                    @click="newCourt.type = sport.id"
                                    :class="newCourt.type === sport.id
                                        ? 'border-primary bg-primary-light text-primary'
                                        : 'border-slate-200 text-slate-600'"
                                    class="flex flex-col items-center gap-1 p-2.5 rounded-xl border-2 transition-all text-xs font-semibold">
                                    <component :is="sport.icon" :size="18" />
                                    {{ sport.label }}
                                </button>
                            </div>
                        </div>
                        <!-- Rate -->
                        <div>
                            <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Rate per Hour (₹) *</label>
                            <input v-model="newCourt.hourly_rate" type="number" placeholder="e.g. 300"
                                class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                        </div>
                        <!-- Court Photo -->
                        <div>
                            <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Service Photo</label>
                            <div class="relative rounded-2xl overflow-hidden"
                                :class="imagePreview ? '' : 'border-2 border-dashed border-slate-200 p-6'">
                                <img v-if="imagePreview" :src="imagePreview" class="w-full h-40 object-cover rounded-2xl" />
                                <div v-else class="flex flex-col items-center gap-2 text-slate-400 pointer-events-none">
                                    <Camera :size="28" class="text-slate-300" />
                                    <p class="text-sm font-medium text-slate-500">Tap to add a photo</p>
                                    <p class="text-xs">JPG, PNG, WebP · Max 5 MB</p>
                                </div>
                                <input type="file" accept="image/jpeg,image/png,image/webp"
                                    @change="handleImageSelect"
                                    class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                                <div v-if="uploadLoading" class="absolute inset-0 bg-white/80 flex items-center justify-center rounded-2xl">
                                    <Loader2 :size="24" class="animate-spin text-primary" />
                                </div>
                                <button v-if="imagePreview && !uploadLoading"
                                    @click.stop="clearImage" type="button"
                                    class="absolute top-2 right-2 w-7 h-7 bg-black/50 rounded-full flex items-center justify-center hover:bg-black/70 transition-colors">
                                    <Trash2 :size="13" class="text-white" />
                                </button>
                            </div>
                        </div>
                        <!-- Description -->
                        <div>
                            <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Description</label>
                            <textarea v-model="newCourt.description" rows="2" placeholder="Amenities, rules, notes..."
                                class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary resize-none"></textarea>
                        </div>
                        <!-- Operating Hours -->
                        <div>
                            <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Operating Hours</label>
                            <div class="grid grid-cols-2 gap-3">
                                <div>
                                    <p class="text-[11px] text-slate-400 mb-1">Opens</p>
                                    <input v-model="newCourt.open_time" type="time"
                                        class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                                </div>
                                <div>
                                    <p class="text-[11px] text-slate-400 mb-1">Closes</p>
                                    <input v-model="newCourt.close_time" type="time"
                                        class="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                                </div>
                            </div>
                        </div>
                        <!-- Peak Hours -->
                        <div v-if="hasPeakHours" class="bg-amber-50 border border-amber-100 rounded-2xl p-4 space-y-3">
                            <div class="flex items-center gap-2">
                                <div class="w-7 h-7 bg-amber-100 rounded-lg flex items-center justify-center">
                                    <Shield :size="14" class="text-amber-600" />
                                </div>
                                <div>
                                    <p class="text-sm font-bold text-slate-800">Peak Hour Settings</p>
                                    <p class="text-[11px] text-slate-500">Set member-only access windows</p>
                                </div>
                            </div>
                            <div>
                                <div class="flex items-center gap-1.5 mb-2">
                                    <Sun :size="13" class="text-amber-500" />
                                    <span class="text-xs font-semibold text-slate-600">Morning Peak</span>
                                </div>
                                <div class="grid grid-cols-2 gap-2">
                                    <input v-model="newCourt.morning_peak_start" type="time"
                                        class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                                    <input v-model="newCourt.morning_peak_end" type="time"
                                        class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                                </div>
                            </div>
                            <div>
                                <div class="flex items-center gap-1.5 mb-2">
                                    <Moon :size="13" class="text-indigo-500" />
                                    <span class="text-xs font-semibold text-slate-600">Evening Peak</span>
                                </div>
                                <div class="grid grid-cols-2 gap-2">
                                    <input v-model="newCourt.evening_peak_start" type="time"
                                        class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                                    <input v-model="newCourt.evening_peak_end" type="time"
                                        class="w-full rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary" />
                                </div>
                            </div>
                            <!-- Members-only toggle -->
                            <label class="flex items-center justify-between cursor-pointer py-1">
                                <div>
                                    <p class="text-sm font-semibold text-slate-800">Peak hours: members only</p>
                                    <p class="text-[11px] text-slate-500">Block walk-in bookings during peak windows</p>
                                </div>
                                <div class="relative ml-3">
                                    <input type="checkbox" v-model="newCourt.peak_members_only" class="sr-only peer" />
                                    <div class="w-11 h-6 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors"></div>
                                    <div class="absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform peer-checked:translate-x-5"></div>
                                </div>
                            </label>
                        </div>

                        <!-- Amenities -->
                        <div>
                            <label class="block text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">Amenities</label>
                            <div class="flex flex-wrap gap-2">
                                <button v-for="tag in AMENITIES_LIST" :key="tag"
                                    type="button"
                                    @click="newCourt.amenities.includes(tag) ? newCourt.amenities.splice(newCourt.amenities.indexOf(tag),1) : newCourt.amenities.push(tag)"
                                    class="px-3 py-1.5 rounded-full text-xs font-semibold transition-all"
                                    :class="newCourt.amenities.includes(tag) ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500'">
                                    {{ tag }}
                                </button>
                            </div>
                        </div>

                        <!-- Submit Button -->
                        <button
                            @click="addCourt"
                            :disabled="addLoading"
                            class="w-full bg-primary hover:bg-primary-dark text-white font-bold py-4 rounded-xl transition-colors flex items-center justify-center gap-2 shadow-fab">
                            <span v-if="addLoading" class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
                            <template v-else>
                                <Check :size="17" />
                                List Service
                            </template>
                        </button>
                    </div>
                </div>
            </div>
        </Transition>

        <!-- Edit now navigates to /my-services/:id/edit (EditServiceView) -->

        <!-- Owner Chat Sheet -->
        <ChatSheet
            v-model="ownerChat.show"
            :booking-id="ownerChat.bookingId"
            :receiver-id="ownerChat.playerId"
            :receiver-name="ownerChat.playerName"
            :court-name="ownerChat.courtName"
        />
    </div>
</template>
