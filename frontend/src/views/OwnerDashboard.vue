<script setup>
import { ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { useRouter, useRoute } from 'vue-router'
import KoLogo from '@/components/KoLogo.vue'
import ChatSheet from '../components/ChatSheet.vue'
import ManageStaffSheet from '../components/ManageStaffSheet.vue'
import SlotBlockSheet from '../components/SlotBlockSheet.vue'
import WalkInSheet from '../components/WalkInSheet.vue'
import ManageSubCourtsSheet from '../components/ManageSubCourtsSheet.vue'
import ManagePricingSheet from '../components/ManagePricingSheet.vue'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    Plus, X, Check, Clock,
    Wind, Flag, Target, Activity, CircleDot, Layers3, Dumbbell, Waves, Swords,
    IndianRupee, Loader2,
    Camera, TrendingUp, CalendarDays, Search, MapPin,
    Flame, Map, Globe, Heart, User, Star, LayoutGrid, Wallet, ArrowDownToLine, MessageSquare,
    ChevronLeft, ChevronRight, Users, Ban, Tag, BarChart3, TrendingDown, UserPlus, Pencil, Trash2, Award
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
const searchQuery = ref('')


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


// ── Staff management ──────────────────────────────────────────────────────────
const staffSheet      = ref({ show: false, court: null })
const staffCourts     = ref([])   // courts where this user is a staff member
const staffBookings   = ref([])
const staffLoading    = ref(false)

const fetchStaffData = async () => {
    staffLoading.value = true
    try {
        const res = await axios.get(`/court-staff/my-courts?user_id=${auth.user?.id}`)
        staffCourts.value = res.data.courts || []
        if (staffCourts.value.length > 0) {
            const bRes = await axios.get(`/bookings?staff_id=${auth.user?.id}`)
            staffBookings.value = bRes.data.records || []
        }
    } catch { staffCourts.value = [] }
    finally { staffLoading.value = false }
}

const openStaffSheet = (court) => { staffSheet.value = { show: true, court } }

// ── Slot blocking ──────────────────────────────────────────────────────────────
const blockSheet   = ref({ show: false, court: null })
const openBlockSheet = (court) => { blockSheet.value = { show: true, court } }

// ── Walk-in booking ────────────────────────────────────────────────────────────
const walkInSheet = ref({ show: false, court: null, subCourts: [] })
const subCourtsByCourtId = ref({})

const openWalkIn = async (court) => {
    if (!subCourtsByCourtId.value[court.id]) {
        try {
            const res = await axios.get(`/sub-courts?court_id=${court.id}`)
            subCourtsByCourtId.value[court.id] = res.data.sub_courts || []
        } catch { subCourtsByCourtId.value[court.id] = [] }
    }
    walkInSheet.value = { show: true, court, subCourts: subCourtsByCourtId.value[court.id] }
}

// ── Sub-courts management ──────────────────────────────────────────────────────
const subCourtSheet = ref({ show: false, court: null })
const openSubCourtSheet = (court) => { subCourtSheet.value = { show: true, court } }

// ── Pricing rules management ───────────────────────────────────────────────────
const pricingSheet = ref({ show: false, court: null })
const openPricingSheet = (court) => { pricingSheet.value = { show: true, court } }

// ── Analytics ─────────────────────────────────────────────────────────────────
const analytics     = ref(null)
const analyticsLoading = ref(false)

const fetchAnalytics = async () => {
    analyticsLoading.value = true
    try {
        const res = await axios.get(`/analytics?owner_id=${auth.user?.id}&period=30`)
        analytics.value = res.data
    } catch { analytics.value = null }
    finally { analyticsLoading.value = false }
}

const hasStaffAccess = computed(() => staffCourts.value.length > 0)
const isStaffManager = (court) => {
    const s = staffCourts.value.find(c => c.id === court.id)
    return s?.role === 'manager'
}
const editCourt     = ref(null)   // court being edited (null = closed)
const editLoading   = ref(false)
const deleteLoading = ref(null)   // court id being deleted

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
    // Also load staff assignments in background
    fetchStaffData()
}

onMounted(() => {
    if (!auth.isLoggedIn) {
        router.push('/login')
        return
    }
    // Support ?tab=earnings or ?tab=reviews deep-link from Profile page
    const tab = route.query.tab
    if (tab === 'earnings')   { activeNavTab.value = 'earnings';   fetchEarnings() }
    else if (tab === 'reviews')   { activeNavTab.value = 'reviews';   fetchOwnerReviews() }
    else if (tab === 'analytics') { activeNavTab.value = 'analytics'; fetchAnalytics() }
    fetchData()
})

const openEdit = (court) => {
    router.push(`/my-venues/${court.id}/edit`)
}

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
    <div class="max-w-md mx-auto bg-white min-h-full h-full flex flex-col shadow-xl relative">

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
        <main class="flex-1 px-4 pb-[calc(6rem+env(safe-area-inset-bottom,0px))]">

            <!-- Section header -->
            <div class="flex items-center justify-between pt-4 pb-3">
                <h3 class="text-slate-900 text-xl font-bold tracking-tight">
                    {{ activeNavTab === 'bookings' ? 'All Bookings' : activeNavTab === 'reviews' ? 'Reviews' : activeNavTab === 'earnings' ? 'Earnings' : activeNavTab === 'analytics' ? 'Analytics' : activeNavTab === 'profile' ? 'Profile' : 'My Venues' }}
                </h3>
                <button v-if="activeNavTab === 'explore'"
                    @click="router.push('/my-venues/new')"
                    class="text-primary text-sm font-semibold">
                    + Add Venue
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
                    <p class="font-extrabold text-slate-700 text-lg">No venues yet</p>
                    <p class="text-sm text-slate-400 mt-1 mb-6">Venues you list will appear here</p>
                    <button @click="router.push('/my-venues/new')"
                        class="bg-primary text-white font-bold py-3 px-8 rounded-xl shadow-fab">
                        Add Service
                    </button>
                </div>

                <!-- Court cards - matching reference design exactly -->
                <div v-else class="space-y-6">
                    <div
                        v-for="(court, idx) in filteredCourts"
                        :key="court.id"
                        @click="router.push(`/my-venues/${court.id}`)"
                        class="flex flex-col bg-white rounded-xl overflow-hidden shadow-sm hover:shadow-md transition-shadow ring-1 ring-slate-100 cursor-pointer active:scale-[0.99]">

                        <!-- Image section -->
                        <div class="relative h-48 w-full bg-slate-200">
                            <img
                                v-if="court.image_url"
                                :src="court.image_url"
                                class="w-full h-full object-cover"
                                onerror="this.style.display='none'" />
                            <div v-else class="w-full h-full flex items-center justify-center bg-slate-100">
                                <component :is="sportOptions.find(s => s.id === court.type)?.icon || LayoutGrid" :size="48" :stroke-width="1.5" class="text-slate-300" />
                            </div>
                            <div class="absolute top-3 right-3 bg-white/95 backdrop-blur rounded-full p-2 shadow-sm border border-slate-100">
                                <Heart :size="16" :stroke-width="2.5" class="text-slate-400" />
                            </div>
                            <div v-if="idx === 0" class="absolute bottom-3 left-3 bg-primary text-white text-[10px] font-bold px-2.5 py-1.5 rounded-lg flex items-center gap-1 shadow-lg shadow-primary/30 tracking-wider">
                                <Flame :size="10" :stroke-width="3" />
                                POPULAR
                            </div>
                        </div>

                        <!-- Card body -->
                        <div class="p-4">
                            <!-- Claim status banners -->
                            <div v-if="court.claim_status === 'pending'" class="mb-3 flex items-center gap-2 bg-amber-50 border border-amber-100 rounded-xl px-3 py-2">
                                <Loader2 :size="12" class="text-amber-500 animate-spin shrink-0" />
                                <p class="text-xs font-bold text-amber-700">Pending admin verification · not visible to players yet</p>
                            </div>
                            <div v-else-if="court.claim_status === 'rejected'" class="mb-3 flex items-center gap-2 bg-red-50 border border-red-100 rounded-xl px-3 py-2">
                                <X :size="12" class="text-red-500 shrink-0" />
                                <p class="text-xs font-bold text-red-600">Claim rejected · please contact support</p>
                            </div>

                            <!-- Name + Rating -->
                            <div class="flex justify-between items-start mb-1">
                                <h4 class="text-slate-900 font-bold text-lg">{{ court.name }}</h4>
                                <div class="flex items-center gap-1 bg-amber-50 px-2 py-1 rounded-lg text-amber-700 font-bold text-[11px] border border-amber-100/50">
                                    <template v-if="court.avg_rating">
                                        <Star :size="11" class="fill-amber-400 text-amber-400" />
                                        <span>{{ court.avg_rating }}</span>
                                    </template>
                                    <template v-else>
                                        <Star :size="11" class="text-slate-300" />
                                        <span class="text-slate-400">New</span>
                                    </template>
                                </div>
                            </div>
                            <!-- Location -->
                            <div class="flex items-center gap-1.5 text-slate-500 text-sm mb-3">
                                <MapPin :size="12" :stroke-width="2.5" class="text-slate-400" />
                                <span>{{ court.location || 'Location not set' }}</span>
                            </div>
                            <!-- Price + manage hint -->
                            <div class="flex items-center justify-between">
                                <div class="flex flex-col">
                                    <span class="text-xs text-slate-400 font-medium">Starting at</span>
                                    <span class="text-primary font-bold text-lg">
                                        ₹{{ court.hourly_rate }}<span class="text-sm font-normal text-slate-500">/hr</span>
                                    </span>
                                </div>
                                <div class="flex items-center gap-2">
                                    <button @click.stop="router.push(`/my-venues/${court.id}/calendar`)"
                                        class="flex items-center gap-1 text-[11px] font-bold text-slate-600 bg-slate-100 px-3 py-1.5 rounded-full active:scale-95 transition-transform">
                                        <CalendarDays :size="11" />
                                        Calendar
                                    </button>
                                    <span class="text-xs font-semibold text-primary bg-primary-light px-3 py-1.5 rounded-full">Manage →</span>
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

            <!-- STAFF TAB -->
            <template v-else-if="activeNavTab === 'staff'">
                <div v-if="staffLoading" class="space-y-3">
                    <div v-for="i in 3" :key="i" class="bg-white rounded-xl p-4 animate-pulse ring-1 ring-slate-100 h-20"></div>
                </div>
                <template v-else>
                    <!-- Courts I manage -->
                    <div class="mb-5">
                        <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3 px-1">Venues I Manage</p>
                        <div class="space-y-2">
                            <div v-for="court in staffCourts" :key="court.id"
                                @click="court.role === 'manager' ? router.push(`/my-venues/${court.id}`) : null"
                                :class="court.role === 'manager' ? 'cursor-pointer active:scale-[0.98]' : ''"
                                class="flex items-center gap-3 bg-white rounded-2xl px-4 py-3 ring-1 ring-slate-100 shadow-sm transition-transform">
                                <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-100 shrink-0">
                                    <img v-if="court.image_url" :src="court.image_url" class="w-full h-full object-cover" />
                                    <div v-else class="w-full h-full flex items-center justify-center">
                                        <Globe :size="16" class="text-slate-300" />
                                    </div>
                                </div>
                                <div class="flex-1 min-w-0">
                                    <p class="font-bold text-slate-800 text-sm truncate">{{ court.name }}</p>
                                    <p class="text-xs text-slate-400 truncate">{{ court.location }}</p>
                                </div>
                                <div class="flex items-center gap-2 shrink-0">
                                    <span class="text-[10px] font-black px-2.5 py-1 rounded-full"
                                        :class="court.role === 'manager' ? 'bg-primary/10 text-primary' : 'bg-slate-100 text-slate-500'">
                                        {{ court.role }}
                                    </span>
                                    <ChevronRight v-if="court.role === 'manager'" :size="14" class="text-slate-300" />
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Walk-in booking for managed courts -->
                    <div v-if="staffCourts.some(c => c.role === 'manager')" class="mb-5">
                        <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3 px-1">Quick Actions</p>
                        <div class="flex gap-2 flex-wrap">
                            <button v-for="sc in staffCourts.filter(c => c.role === 'manager')" :key="'wi-'+sc.id"
                                @click="openWalkIn(sc)"
                                class="flex items-center gap-1.5 bg-primary text-white font-bold py-2.5 px-4 rounded-xl text-xs">
                                <UserPlus :size="12" />
                                Walk-in · {{ sc.name }}
                            </button>
                        </div>
                    </div>

                    <!-- Bookings for my courts -->
                    <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3 px-1">Bookings to Manage</p>
                    <div v-if="staffBookings.length === 0" class="text-center py-12 bg-slate-50/50 rounded-3xl border-2 border-dashed border-slate-100">
                        <CalendarDays :size="28" class="text-slate-300 mx-auto mb-2" />
                        <p class="text-sm font-bold text-slate-500">No bookings yet</p>
                    </div>
                    <div v-else class="space-y-3">
                        <div v-for="booking in staffBookings" :key="booking.id"
                            class="flex flex-col bg-white rounded-xl ring-1 ring-slate-100 p-4">
                            <div class="flex items-start gap-3">
                                <div class="shrink-0 w-12 h-12 rounded-xl flex flex-col items-center justify-center text-white"
                                    :class="booking.status === 'cancelled' ? 'bg-slate-300' : 'bg-primary'">
                                    <span class="text-base font-bold leading-none">{{ new Date(booking.start_time).getDate() }}</span>
                                    <span class="text-[9px] font-semibold uppercase">{{ new Date(booking.start_time).toLocaleDateString('en-IN', { month: 'short' }) }}</span>
                                </div>
                                <div class="flex-1 min-w-0">
                                    <p class="font-bold text-slate-900 text-sm truncate">{{ booking.court_name }}</p>
                                    <p class="text-xs text-slate-500 truncate">{{ booking.user_name || 'Unknown player' }}</p>
                                    <div class="flex items-center gap-1 text-xs text-slate-400 mt-0.5">
                                        <Clock :size="10" />
                                        {{ formatTime(booking.start_time) }} – {{ formatTime(booking.end_time) }}
                                    </div>
                                    <div class="flex items-center justify-between mt-2">
                                        <span :class="booking.status === 'confirmed' ? 'text-primary bg-primary-light' : booking.status === 'cancelled' ? 'text-red-500 bg-red-50' : 'text-amber-600 bg-amber-50'"
                                            class="text-[10px] font-bold px-2 py-1 rounded-full capitalize">
                                            {{ booking.status }}
                                        </span>
                                        <span class="font-bold text-sm text-slate-800">₹{{ booking.total_price }}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </template>
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

            <!-- ANALYTICS TAB -->
            <template v-else-if="activeNavTab === 'analytics'">
                <div v-if="analyticsLoading" class="space-y-3">
                    <div v-for="i in 4" :key="i" class="bg-white rounded-xl p-4 animate-pulse ring-1 ring-slate-100">
                        <div class="h-4 bg-slate-200 rounded w-1/2 mb-2"></div>
                        <div class="h-6 bg-slate-200 rounded w-1/3"></div>
                    </div>
                </div>
                <template v-else-if="analytics">
                    <!-- Summary cards -->
                    <div class="grid grid-cols-2 gap-3 mb-5">
                        <div class="col-span-2 bg-gradient-to-r from-primary to-blue-600 rounded-2xl p-4 text-white">
                            <p class="text-xs font-semibold opacity-80 mb-1">Total Revenue (30 days)</p>
                            <p class="text-3xl font-extrabold">₹{{ Number(analytics.summary?.total_revenue || 0).toLocaleString('en-IN') }}</p>
                            <p class="text-xs opacity-70 mt-1">{{ analytics.summary?.total_bookings || 0 }} bookings · {{ analytics.summary?.unique_players || 0 }} players</p>
                        </div>
                        <div class="bg-white rounded-2xl p-4 ring-1 ring-slate-100">
                            <p class="text-[11px] font-semibold text-slate-400 mb-1">Avg Booking</p>
                            <p class="text-xl font-bold text-slate-800">₹{{ Number(analytics.summary?.avg_booking_value || 0).toFixed(0) }}</p>
                        </div>
                        <div class="bg-white rounded-2xl p-4 ring-1 ring-slate-100">
                            <p class="text-[11px] font-semibold text-slate-400 mb-1">Cancel Rate</p>
                            <p class="text-xl font-bold" :class="analytics.cancel_rate > 20 ? 'text-red-500' : 'text-emerald-600'">
                                {{ analytics.cancel_rate }}%
                            </p>
                        </div>
                    </div>

                    <!-- Revenue by day chart (simple bar) -->
                    <div v-if="analytics.revenue_by_day?.length" class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 mb-4">
                        <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3">Revenue – Last 30 Days</p>
                        <div class="flex items-end gap-1 h-20">
                            <div v-for="day in analytics.revenue_by_day.slice(-20)" :key="day.day"
                                class="flex-1 bg-primary/20 rounded-t hover:bg-primary/40 transition-colors relative group"
                                :style="`height: ${Math.max(4, (day.revenue / Math.max(...analytics.revenue_by_day.map(d=>d.revenue))) * 80)}px`">
                                <div class="absolute -top-6 left-1/2 -translate-x-1/2 bg-slate-800 text-white text-[9px] px-1.5 py-0.5 rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-10">
                                    ₹{{ Number(day.revenue).toLocaleString('en-IN') }}
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Top courts -->
                    <div v-if="analytics.top_courts?.length" class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 mb-4">
                        <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3">Top Courts</p>
                        <div class="space-y-2">
                            <div v-for="(court, i) in analytics.top_courts" :key="court.id"
                                class="flex items-center gap-3">
                                <span class="w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-black shrink-0"
                                    :class="i === 0 ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-500'">
                                    {{ i + 1 }}
                                </span>
                                <div class="flex-1 min-w-0">
                                    <p class="text-sm font-bold text-slate-800 truncate">{{ court.name }}</p>
                                    <p class="text-[11px] text-slate-400">{{ court.booking_count }} bookings</p>
                                </div>
                                <p class="text-sm font-extrabold text-primary shrink-0">₹{{ Number(court.revenue).toLocaleString('en-IN') }}</p>
                            </div>
                        </div>
                    </div>

                    <!-- Peak hours -->
                    <div v-if="analytics.peak_hours?.length" class="bg-white rounded-2xl p-4 ring-1 ring-slate-100 mb-4">
                        <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3">Busiest Hours</p>
                        <div class="space-y-2">
                            <div v-for="ph in analytics.peak_hours" :key="ph.hour" class="flex items-center gap-3">
                                <span class="text-xs font-bold text-slate-500 w-16 shrink-0">
                                    {{ ph.hour > 12 ? ph.hour - 12 : ph.hour }}:00 {{ ph.hour >= 12 ? 'PM' : 'AM' }}
                                </span>
                                <div class="flex-1 bg-slate-100 rounded-full h-2">
                                    <div class="bg-primary h-2 rounded-full transition-all"
                                        :style="`width: ${(ph.count / analytics.peak_hours[0].count) * 100}%`"></div>
                                </div>
                                <span class="text-xs font-bold text-slate-600 shrink-0 w-8 text-right">{{ ph.count }}</span>
                            </div>
                        </div>
                    </div>

                    <!-- Heatmap (day × hour) -->
                    <div v-if="analytics.heatmap && Object.keys(analytics.heatmap).length" class="bg-white rounded-2xl p-4 ring-1 ring-slate-100">
                        <p class="text-[11px] font-black text-slate-400 uppercase tracking-wider mb-3">Occupancy Heatmap</p>
                        <div class="overflow-x-auto">
                            <table class="w-full text-[9px]">
                                <thead>
                                    <tr>
                                        <th class="w-8 text-slate-300"></th>
                                        <th v-for="h in [6,8,10,12,14,16,18,20,22]" :key="h" class="text-slate-400 font-medium pb-1 text-center">
                                            {{ h > 12 ? h - 12 : h }}{{ h >= 12 ? 'p' : 'a' }}
                                        </th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="(dayLabel, dow) in ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']" :key="dow">
                                        <td class="text-[9px] text-slate-400 font-bold pr-1">{{ dayLabel }}</td>
                                        <td v-for="h in [6,8,10,12,14,16,18,20,22]" :key="h" class="p-0.5">
                                            <div class="w-5 h-5 rounded"
                                                :style="`background: rgba(43,108,238,${Math.min(1, (analytics.heatmap[dow]?.[h] || 0) / 5) * 0.8 + 0.05})`">
                                            </div>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </template>
                <div v-else class="text-center py-20 bg-slate-50/50 rounded-3xl border-2 border-dashed border-slate-100">
                    <BarChart3 :size="36" class="text-slate-300 mx-auto mb-3" />
                    <p class="font-bold text-slate-500">No analytics data yet</p>
                    <p class="text-sm text-slate-400 mt-1">Data appears once you have bookings</p>
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
        <nav class="fixed bottom-0 left-0 right-0 max-w-md mx-auto bg-white/95 backdrop-blur border-t border-slate-100 px-6 pt-3 flex justify-between items-center z-20 pb-[max(0.75rem,env(safe-area-inset-bottom,0px))]">
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
                    @click="router.push('/my-venues/new')"
                    class="bg-primary text-white size-14 rounded-full shadow-fab flex items-center justify-center border-4 border-white">
                    <Plus :size="28" />
                </button>
            </div>

            <button @click="activeNavTab = 'analytics'; if (!analytics) fetchAnalytics()"
                :class="activeNavTab === 'analytics' ? 'text-primary' : 'text-slate-400'"
                class="flex flex-col items-center gap-1.5 px-2">
                <BarChart3 :size="20" :stroke-width="2.5" />
                <span class="text-[10px] font-bold tracking-tight">Stats</span>
            </button>

            <button @click="activeNavTab = 'profile'"
                :class="activeNavTab === 'profile' ? 'text-primary' : 'text-slate-400'"
                class="flex flex-col items-center gap-1.5 px-2">
                <User :size="20" :stroke-width="2.5" />
                <span class="text-[10px] font-bold tracking-tight">Profile</span>
            </button>
        </nav>

        <!-- Owner Chat Sheet -->
        <ChatSheet
            v-model="ownerChat.show"
            :booking-id="ownerChat.bookingId"
            :receiver-id="ownerChat.playerId"
            :receiver-name="ownerChat.playerName"
            :court-name="ownerChat.courtName"
        />

        <ManageStaffSheet
            v-model="staffSheet.show"
            :court="staffSheet.court"
        />

        <SlotBlockSheet
            v-model="blockSheet.show"
            :court="blockSheet.court"
            @blocked="fetchData"
        />

        <WalkInSheet
            v-model="walkInSheet.show"
            :court="walkInSheet.court"
            :sub-courts="walkInSheet.subCourts"
            @booked="fetchData"
        />

        <ManageSubCourtsSheet
            v-model="subCourtSheet.show"
            :court="subCourtSheet.court"
        />

        <ManagePricingSheet
            v-model="pricingSheet.show"
            :court="pricingSheet.court"
        />
    </div>
</template>
