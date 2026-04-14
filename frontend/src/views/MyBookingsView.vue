<script setup>
import { ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useToastStore } from '../stores/toast'
import {
    CalendarDays, Clock,
    CheckCircle2, XCircle, AlertCircle,
    Trophy, Star, X, Loader2, Share2
} from 'lucide-vue-next'

const router = useRouter()
const auth = useAuthStore()
const toast = useToastStore()

const bookings = ref([])
const loading = ref(true)
const activeFilter = ref('upcoming')
const cancellingId = ref(null)
const reviewedIds = ref(new Set())
const ratingModal = ref({ show: false, booking: null, rating: 0, comment: '', loading: false })

const now = new Date()

const upcoming = computed(() =>
    bookings.value.filter(b => parseLocal(b.start_time) >= now && b.status !== 'cancelled')
)
const past = computed(() =>
    bookings.value.filter(b => parseLocal(b.start_time) < now || b.status === 'cancelled')
)
const displayedBookings = computed(() =>
    activeFilter.value === 'upcoming' ? upcoming.value : past.value
)

const statusConfig = {
    confirmed: { label: 'Confirmed', icon: CheckCircle2, cls: 'text-primary bg-primary-light' },
    pending:   { label: 'Pending',   icon: AlertCircle,  cls: 'text-amber-600 bg-amber-50' },
    cancelled: { label: 'Cancelled', icon: XCircle,      cls: 'text-red-500 bg-red-50' },
}
const getStatus = (s) => statusConfig[s] || statusConfig.pending

// Parse "YYYY-MM-DD HH:MM:SS" as local time — avoids browser UTC timezone shift
const parseLocal = (dt) => { const [d, t] = String(dt).split(' '); return new Date(`${d}T${t || '00:00:00'}`) }
const formatDate = (dt) => parseLocal(dt).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })
const formatTime = (dt) => parseLocal(dt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })

onMounted(async () => {
    if (!auth.isLoggedIn) { router.push('/login'); return }
    try {
        const res = await axios.get(`/bookings?user_id=${auth.user?.id}`)
        bookings.value = res.data.records || []
    } catch {
        bookings.value = []
    } finally {
        loading.value = false
    }
})

// ── Cancel ────────────────────────────────────────────────────────────────────

const cancelBooking = async (booking) => {
    if (cancellingId.value === booking.id) return   // prevent double-tap
    if (!confirm(`Cancel booking at ${booking.court_name}? This cannot be undone.`)) return
    cancellingId.value = booking.id
    try {
        await axios.delete(`/bookings/${booking.id}`, { data: { user_id: auth.user?.id } })
        toast.success('Booking cancelled')
        booking.status = 'cancelled'
    } catch (err) {
        const msg = err.response?.data?.message || ''
        if (msg.toLowerCase().includes('already cancelled') || err.response?.status === 404) {
            // Already cancelled in DB — just reflect it in UI
            booking.status = 'cancelled'
        } else {
            toast.error(msg || 'Could not cancel booking')
        }
    } finally {
        cancellingId.value = null
    }
}

// ── Rating ────────────────────────────────────────────────────────────────────

const openRatingModal = (booking) => {
    ratingModal.value = { show: true, booking, rating: 0, comment: '', loading: false }
}

const submitRating = async () => {
    const { booking, rating, comment } = ratingModal.value
    if (!rating) return
    ratingModal.value.loading = true
    try {
        await axios.post('/reviews', {
            court_id: booking.court_id, user_id: auth.user?.id,
            booking_id: booking.id, rating, comment,
        })
        toast.success('Thanks for your review!')
        reviewedIds.value = new Set([...reviewedIds.value, booking.id])
        ratingModal.value.show = false
    } catch (err) {
        toast.error(err.response?.data?.message || 'Failed to submit review')
    } finally {
        ratingModal.value.loading = false
    }
}
</script>

<template>
    <div class="min-h-screen bg-slate-50">
        <!-- Teleport contents to Global Header -->
        <Teleport to="#header-extra">
            <!-- Tabs -->
            <div class="flex px-5 border-t border-slate-50 bg-white">
                <button @click="activeFilter = 'upcoming'"
                    class="flex-1 py-3 text-xs font-bold border-b-2 transition-all"
                    :class="activeFilter === 'upcoming' ? 'border-primary text-primary' : 'border-transparent text-slate-400'">
                    UPCOMING
                    <span v-if="upcoming.length" class="ml-1 bg-primary text-white text-[9px] px-1.5 py-0.5 rounded-full">
                        {{ upcoming.length }}
                    </span>
                </button>
                <button @click="activeFilter = 'past'"
                    class="flex-1 py-3 text-xs font-bold border-b-2 transition-all"
                    :class="activeFilter === 'past' ? 'border-primary text-primary' : 'border-transparent text-slate-400'">
                    PAST RECORDS
                </button>
            </div>
        </Teleport>

        <!-- Content -->
        <div class="px-5 py-5 pb-8">
            <!-- Loading -->
            <div v-if="loading" class="space-y-4">
                <div v-for="i in 3" :key="i" class="card p-4 animate-pulse">
                    <div class="flex gap-3">
                        <div class="w-12 h-12 bg-slate-200 rounded-xl shrink-0"></div>
                        <div class="flex-1 space-y-2">
                            <div class="h-4 bg-slate-200 rounded w-2/3"></div>
                            <div class="h-3 bg-slate-200 rounded w-1/2"></div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Empty State -->
            <div v-else-if="displayedBookings.length === 0" class="text-center py-16">
                <div class="w-16 h-16 bg-white rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-sm border border-slate-100">
                    <Trophy :size="32" :stroke-width="2" class="text-slate-300" />
                </div>
                <p class="font-semibold text-slate-700">
                    {{ activeFilter === 'upcoming' ? 'No upcoming bookings' : 'No past bookings' }}
                </p>
                <p class="text-sm text-slate-400 mt-1 mb-5">
                    {{ activeFilter === 'upcoming' ? 'Find a court and book your next game' : 'Your played sessions will appear here' }}
                </p>
                <button v-if="activeFilter === 'upcoming'" @click="router.push('/')" class="btn-primary text-sm px-6 py-2.5">
                    Explore Courts
                </button>
            </div>

            <!-- Booking Cards -->
            <div v-else class="space-y-4">
                <div v-for="booking in displayedBookings" :key="booking.id" class="card p-4">
                    <div class="flex gap-3 items-start">
                        <!-- Date block -->
                        <div class="shrink-0 w-12 h-12 rounded-xl flex flex-col items-center justify-center text-white"
                            :class="booking.status === 'cancelled' ? 'bg-slate-400' : 'bg-primary'">
                            <span class="text-lg font-bold leading-none">{{ parseLocal(booking.start_time).getDate() }}</span>
                            <span class="text-[10px] font-semibold uppercase">{{ parseLocal(booking.start_time).toLocaleDateString('en-IN', { month: 'short' }) }}</span>
                        </div>

                        <div class="flex-1 min-w-0">
                            <div class="flex items-start justify-between gap-2">
                                <h3 class="font-bold text-slate-900 text-[15px] truncate">{{ booking.court_name || 'Court Booking' }}</h3>
                                <span :class="[getStatus(booking.status).cls, 'flex items-center gap-1 text-[10px] font-bold px-2 py-1 rounded-full shrink-0']">
                                    <component :is="getStatus(booking.status).icon" :size="10" />
                                    {{ getStatus(booking.status).label }}
                                </span>
                            </div>

                            <div class="flex items-center gap-3 mt-1.5 text-xs text-slate-500">
                                <span class="flex items-center gap-1">
                                    <Clock :size="11" :stroke-width="2" />
                                    {{ formatTime(booking.start_time) }} – {{ formatTime(booking.end_time) }}
                                </span>
                                <span class="flex items-center gap-1">
                                    <CalendarDays :size="11" :stroke-width="2" />
                                    {{ formatDate(booking.start_time) }}
                                </span>
                            </div>

                            <div class="flex items-center justify-between mt-3 pt-3 border-t border-slate-50">
                                <span class="text-xs text-slate-400 font-medium capitalize">
                                    {{ booking.type === 'hourly' ? 'Hourly slot' : 'Membership' }}
                                </span>
                                <span class="font-bold text-primary text-sm">₹{{ booking.total_price }}</span>
                            </div>

                            <!-- Action row -->
                            <div v-if="booking.status !== 'cancelled'" class="flex gap-2 mt-3">
                                <!-- Cancel upcoming -->
                                <button v-if="activeFilter === 'upcoming'"
                                    @click="cancelBooking(booking)"
                                    :disabled="cancellingId === booking.id"
                                    class="flex items-center gap-1 text-xs font-semibold px-3 py-2 rounded-xl bg-red-50 text-red-500 hover:bg-red-100 transition-colors disabled:opacity-50">
                                    <Loader2 v-if="cancellingId === booking.id" :size="11" class="animate-spin" />
                                    <XCircle v-else :size="11" />
                                    Cancel Booking
                                </button>
                                <!-- Rate + Share past -->
                                <template v-else>
                                    <button v-if="!reviewedIds.has(booking.id)"
                                        @click="openRatingModal(booking)"
                                        class="flex items-center gap-1 text-xs font-semibold px-3 py-2 rounded-xl bg-amber-50 text-amber-600 hover:bg-amber-100 transition-colors">
                                        <Star :size="11" />
                                        Rate Court
                                    </button>
                                    <span v-else class="text-[11px] font-semibold text-primary flex items-center gap-1 px-1">
                                        <Star :size="11" class="fill-primary text-primary" /> Reviewed
                                    </span>
                                    <button
                                        @click="router.push(`/post/create?booking_id=${booking.id}&court_id=${booking.court_id}&court_name=${encodeURIComponent(booking.court_name)}`)"
                                        class="flex items-center gap-1 text-xs font-semibold px-3 py-2 rounded-xl bg-primary/5 text-primary hover:bg-primary/10 transition-colors">
                                        <Share2 :size="11" />
                                        Share Experience
                                    </button>
                                </template>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Rating Bottom Sheet -->
        <Transition
            enter-active-class="transition duration-250 ease-out"
            enter-from-class="opacity-0"
            enter-to-class="opacity-100"
            leave-active-class="transition duration-150 ease-in"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0">
            <div v-if="ratingModal.show" class="fixed inset-0 bg-black/50 z-50 flex items-end" @click.self="ratingModal.show = false">
                <div class="bg-white w-full rounded-t-3xl px-5 pt-5 pb-10">
                    <div class="flex items-center justify-between mb-1">
                        <h3 class="font-bold text-slate-900 text-base">Rate Your Experience</h3>
                        <button @click="ratingModal.show = false" class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center">
                            <X :size="16" class="text-slate-500" />
                        </button>
                    </div>
                    <p class="text-sm text-slate-500 mb-5">{{ ratingModal.booking?.court_name }}</p>

                    <!-- Stars -->
                    <div class="flex gap-2 justify-center mb-5">
                        <button v-for="n in 5" :key="n" @click="ratingModal.rating = n" class="active:scale-90 transition-transform">
                            <Star :size="40"
                                :class="n <= ratingModal.rating ? 'text-amber-400 fill-amber-400' : 'text-slate-200 fill-slate-200'" />
                        </button>
                    </div>

                    <textarea v-model="ratingModal.comment" placeholder="Share your experience (optional)..." class="input-field resize-none mb-4" rows="3" />

                    <div class="flex gap-3">
                        <button @click="ratingModal.show = false" class="btn-ghost flex-1">Skip</button>
                        <button @click="submitRating" :disabled="!ratingModal.rating || ratingModal.loading"
                            class="btn-primary flex-1 flex items-center justify-center gap-2">
                            <Loader2 v-if="ratingModal.loading" :size="16" class="animate-spin" />
                            <template v-else>Submit Review</template>
                        </button>
                    </div>
                </div>
            </div>
        </Transition>
    </div>
</template>
